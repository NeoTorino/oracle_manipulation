// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract SimOracle is AccessControl {
    using Checkpoints for Checkpoints.Trace208;
    using SafeCast for uint256;

    bytes32 public constant PUBLISHER_ROLE = keccak256("PUBLISHER_ROLE");

    Checkpoints.Trace208 internal _history;

    event Update(uint48 timepoint, uint208 price, uint80 roundId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PUBLISHER_ROLE, msg.sender);
    }

    // Same shape as the audited function: the caller picks the timepoint, nothing bounds it.
    function publishPrice(uint48 timepoint, uint208 price)
        public
        virtual
        onlyRole(PUBLISHER_ROLE)
        returns (uint80)
    {
        uint80 roundId = _history.length().toUint80();
        _history.push(timepoint, price);
        emit Update(timepoint, price, roundId);
        return roundId;
    }

    // Price that was "in force" at a given time (what a redemption/settlement would use)
    function priceAt(uint48 timepoint) public view returns (uint208) {
        return _history.upperLookup(timepoint);
    }

    // Price a "latestRoundData"-style consumer would read
    function latestPrice() public view returns (uint208) {
        return _history.latest();
    }

    function now_() external view returns (uint256) {
        return block.timestamp;
    }

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        uint256 n = _history.length();
        require(n > 0, "empty");
        Checkpoints.Checkpoint208 memory c = _history._checkpoints[n - 1];
        return (uint80(n - 1), int256(uint256(c._value)), c._key, c._key, uint80(n - 1));
    }

    // Typical consumer staleness check: reverts (underflow) if updatedAt is in the future
    function isFresh(uint256 maxAge) external view returns (bool) {
        (, , , uint256 updatedAt, ) = this.latestRoundData();
        return block.timestamp - updatedAt <= maxAge;
    }
}