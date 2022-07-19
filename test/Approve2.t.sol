// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {Approve2} from "../src/Approve2.sol";

contract Approve2Test is DSTestPlus {
    Approve2 approve2;

    function setUp() public {
        approve2 = new Approve2();
    }
}
