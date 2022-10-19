// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Permit2} from "../../src/Permit2.sol";
import {PackedAllowance} from "../../src/Permit2Utils.sol";

contract MockPermit2 is Permit2 {
    function setAllowance(address from, address token, address spender, uint32 nonce)
        public
        returns (PackedAllowance memory allowed)
    {
        allowed = allowance[from][token][spender];
        allowance[from][token][spender].nonce = nonce;
    }
}
