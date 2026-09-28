// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SimOracle} from "./SimOracle.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract SimMitigation is SimOracle {
    using Checkpoints for Checkpoints.Trace208; // <-- the missing line
    using SafeCast for uint256;

    uint48 public maxBackdate;      // per-asset: e.g. 86400 (24h) for T-bills
    uint16 public maxDeviationBps;  // per-asset: e.g. 100 = 1% per update

    constructor(uint48 _maxBackdate, uint16 _maxDeviationBps) {
        maxBackdate = _maxBackdate;
        maxDeviationBps = _maxDeviationBps;
    }

    function publishPrice(uint48 timepoint, uint208 price)
        public
        override
        onlyRole(PUBLISHER_ROLE)
        returns (uint80)
    {
        require(timepoint <= block.timestamp, "future timepoint");
        require(timepoint + maxBackdate >= block.timestamp, "too old");

        if (_history.length() > 0) {
            uint208 last = _history.latest();
            uint256 diff = price > last ? price - last : last - price;
            require(diff * 10_000 <= uint256(last) * maxDeviationBps, "deviation too large");
        }
        return super.publishPrice(timepoint, price);
    }
}