// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";
import {Allowance} from "../../src/libraries/Allowance.sol";

contract MockAllowance {
    using Allowance for IAllowanceTransfer.PackedAllowance;

    function testPack(uint160 amount, uint48 expiration, uint48 nonce) public pure returns (uint256 word) {
        return Allowance.pack(amount, expiration, nonce);
    }
}
