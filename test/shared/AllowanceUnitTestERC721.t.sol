// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../mocks/MockPermit2ERC721.sol";
import {BaseAllowanceUnitTest} from "./BaseAllowanceUnitTest.sol";
import {TokenProviderERC721} from "../utils/TokenProviderERC721.sol";

contract AllowanceUnitTestERC721 is BaseAllowanceUnitTest, TokenProviderERC721 {
    function setUp() public override {
        permit2 = new MockPermit2ERC721();
        initializeTokens();
    }

    function allowance(address from, address token, address spender, uint256 tokenId)
        public
        view
        override
        returns (uint160, uint48, uint48)
    {
        (address spender1, uint48 expiration1, uint48 nonce1) =
            MockPermit2ERC721(address(permit2)).allowance(from, token, tokenId);
        return (uint160(spender1), expiration1, nonce1);
    }

    function token() public view override returns (address) {
        return address(_token1);
    }
}
