// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Permit2ERC721} from "../../src/ERC721/Permit2ERC721.sol";
import {IAllowanceTransferERC721} from "../../src/ERC721/interfaces/IAllowanceTransferERC721.sol";
import {SignatureTransferERC721} from "../../src/ERC721/SignatureTransferERC721.sol";
import {AllowanceERC721} from "../../src/ERC721/libraries/AllowanceERC721.sol";
import {IMockPermit2} from "../mocks/IMockPermit2.sol";

contract MockPermit2ERC721 is IMockPermit2, Permit2ERC721 {
    function doStore(address from, address token, address spender, uint256 word) public override {
        IAllowanceTransferERC721.PackedAllowance storage allowed = allowance[from][token][spender];
        assembly {
            sstore(allowed.slot, word)
        }
    }

    function getStore(address from, address token, address spender) public view override returns (uint256 word) {
        IAllowanceTransferERC721.PackedAllowance storage allowed = allowance[from][token][spender];
        assembly {
            word := sload(allowed.slot)
        }
    }

    function mockUpdateSome(address from, address token, address spender, uint160 data, uint48 expiration)
        public
        override
    {
        IAllowanceTransferERC721.PackedAllowance storage allowed = allowance[from][token][spender];
        AllowanceERC721.updateTokenIdAndExpiration(allowed, data, expiration);
    }

    function mockUpdateAll(address from, address token, address spender, uint160 data, uint48 expiration, uint48 nonce)
        public
        override
    {
        IAllowanceTransferERC721.PackedAllowance storage allowed = allowance[from][token][spender];
        AllowanceERC721.updateAll(allowed, data, expiration, nonce);
    }

    function useUnorderedNonce(address from, uint256 nonce) public override {
        _useUnorderedNonce(from, nonce);
    }
}
