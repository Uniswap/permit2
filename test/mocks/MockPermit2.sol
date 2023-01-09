// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Permit2} from "../../src/ERC20/Permit2.sol";
import {IAllowanceTransfer} from "../../src/ERC20/interfaces/IAllowanceTransfer.sol";
import {Allowance} from "../../src/ERC20/libraries/Allowance.sol";
import {IMockPermit2} from "../mocks/IMockPermit2.sol";

contract MockPermit2 is IMockPermit2, Permit2 {
    function doStore(address from, address token, address spender, uint256 word) public override {
        IAllowanceTransfer.PackedAllowance storage allowed = allowance[from][token][spender];
        assembly {
            sstore(allowed.slot, word)
        }
    }

    function getStore(address from, address token, address spender) public view override returns (uint256 word) {
        IAllowanceTransfer.PackedAllowance storage allowed = allowance[from][token][spender];
        assembly {
            word := sload(allowed.slot)
        }
    }

    function mockUpdateSome(address from, address token, address spender, uint160 data, uint48 expiration)
        public
        override
    {
        IAllowanceTransfer.PackedAllowance storage allowed = allowance[from][token][spender];
        Allowance.updateAmountAndExpiration(allowed, data, expiration);
    }

    function mockUpdateAll(address from, address token, address spender, uint160 data, uint48 expiration, uint48 nonce)
        public
        override
    {
        IAllowanceTransfer.PackedAllowance storage allowed = allowance[from][token][spender];
        Allowance.updateAll(allowed, data, expiration, nonce);
    }

    function useUnorderedNonce(address from, uint256 nonce) public override {
        _useUnorderedNonce(from, nonce);
    }
}
