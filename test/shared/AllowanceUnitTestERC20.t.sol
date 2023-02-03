// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../mocks/MockPermit2.sol";
import {BaseAllowanceUnitTest} from "./BaseAllowanceUnitTest.sol";
import {TokenProviderERC20} from "../utils/TokenProviderERC20.sol";
import {Allowance} from "../../src/ERC20/libraries/Allowance.sol";

contract AllowanceUnitTestERC20 is BaseAllowanceUnitTest, TokenProviderERC20 {
    function setUp() public override {
        permit2 = new MockPermit2();
        initializeTokens();
    }

    function allowance(address from, address token, address spender, uint256 tokenId)
        public
        view
        override
        returns (uint160, uint48, uint48)
    {
        return MockPermit2(address(permit2)).allowance(from, token, spender);
    }

    function token() public view override returns (address) {
        return address(_token1);
    }
}
