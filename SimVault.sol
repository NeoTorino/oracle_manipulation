// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SimOracle} from "./SimOracle.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract SimVault {
    using SafeCast for uint256;

    SimOracle public immutable oracle;

    struct Request { uint256 units; uint48 requestedAt; bool settled; }
    mapping(address => Request) public requests;
    mapping(address => uint256) public payout; // internal accounting, no real tokens needed

    constructor(SimOracle _oracle) { oracle = _oracle; }

    function requestRedeem(uint256 units) external {
        requests[msg.sender] = Request(units, block.timestamp.toUint48(), false);
    }

    // Anyone can settle later, e.g. after the fund's daily NAV is published
    function settle(address user) external {
        Request storage r = requests[user];
        require(r.units > 0 && !r.settled, "nothing to settle");
        r.settled = true;
        payout[user] = r.units * oracle.priceAt(r.requestedAt);
    }
}