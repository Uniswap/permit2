// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../mocks/MockPermit2ERC721.sol";
import {BaseAllowanceUnitTest} from "./BaseAllowanceUnitTest.sol";
import {TokenProviderERC721} from "../utils/TokenProviderERC721.sol";

contract AllowanceUnitTestERC721 is TokenProviderERC721, BaseAllowanceUnitTest {
    function setUp() public override {
        permit2 = new MockPermit2ERC721();
        initializeERC721TestTokens();
    }

    function allowance(address from, address token, address spender)
        public
        view
        override
        returns (uint160, uint48, uint48)
    {
        return MockPermit2ERC721(address(permit2)).allowance(from, token, spender);
    }

    function token1() public view override returns (address) {
        return address(_token1);
    }
}
