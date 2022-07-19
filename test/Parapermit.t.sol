// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {Parapermit} from "../src/Parapermit.sol";

contract SampleContractTest is DSTestPlus {
    Parapermit parapermit;

    function setUp() public {
        parapermit = new Parapermit();
    }
}
