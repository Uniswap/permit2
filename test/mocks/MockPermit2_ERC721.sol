// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Permit2_ERC721} from "../../src/ERC721/Permit2_ERC721.sol";
import {IAllowanceTransfer_ERC721} from "../../src/ERC721/interfaces/IAllowanceTransfer_ERC721.sol";
import {SignatureTransfer_ERC721} from "../../src/ERC721/SignatureTransfer_ERC721.sol";
import {Allowance_ERC721} from "../../src/ERC721/libraries/Allowance_ERC721.sol";
import {IMockPermit2} from "../mocks/IMockPermit2.sol";

contract MockPermit2_ERC721 is IMockPermit2, Permit2_ERC721 {
    function doStore(address from, address token, address spender, uint256 word) public override {
        IAllowanceTransfer_ERC721.PackedAllowance storage allowed = allowance[from][token][spender];
        assembly {
            sstore(allowed.slot, word)
        }
    }

    function getStore(address from, address token, address spender) public view override returns (uint256 word) {
        IAllowanceTransfer_ERC721.PackedAllowance storage allowed = allowance[from][token][spender];
        assembly {
            word := sload(allowed.slot)
        }
    }

    function mockUpdateSome(address from, address token, address spender, uint160 data, uint48 expiration)
        public
        override
    {
        IAllowanceTransfer_ERC721.PackedAllowance storage allowed = allowance[from][token][spender];
        Allowance_ERC721.updateTokenIdAndExpiration(allowed, data, expiration);
    }

    function mockUpdateAll(address from, address token, address spender, uint160 data, uint48 expiration, uint48 nonce)
        public
        override
    {
        IAllowanceTransfer_ERC721.PackedAllowance storage allowed = allowance[from][token][spender];
        Allowance_ERC721.updateAll(allowed, data, expiration, nonce);
    }

    function useUnorderedNonce(address from, uint256 nonce) public override {
        _useUnorderedNonce(from, nonce);
    }
}
