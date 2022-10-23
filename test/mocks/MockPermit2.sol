// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Permit2} from "../../src/Permit2.sol";
import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";

contract MockPermit2 is Permit2 {
    function setAllowance(address from, address token, address spender, uint32 nonce)
        public
        returns (IAllowanceTransfer.PackedAllowance memory allowed)
    {
        allowed = allowance[from][token][spender];
        allowance[from][token][spender].nonce = nonce;
    }

    function useUnorderedNonce(address from, uint256 nonce) public {
        _useUnorderedNonce(from, nonce);
    }
}
