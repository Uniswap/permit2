// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Allowance} from "../src/libraries/Allowance.sol";

contract AllowanceUnitTest is Test, TokenProvider {
    MockPermit2 permit2;

    address from = address(0xBEEE);
    address spender = address(0xBBBB);

    function setUp() public {
        permit2 = new MockPermit2();
        initializeERC20Tokens();
    }

    function testUpdateAmountExpirationRandomly(uint160 amount, uint48 expiration) public {
        address token = address(token1);

        (,, uint48 nonce) = permit2.allowance(from, token, spender);

        permit2.mockUpdateAmountAndExpiration(from, token, spender, amount, expiration);

        uint48 timestampAfterUpdate = expiration == 0 ? uint48(block.timestamp) : expiration;

        (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, token, spender);
        assertEq(amount, amount1);
        assertEq(timestampAfterUpdate, expiration1);
        /// nonce shouldnt change
        assertEq(nonce, nonce1);
    }

    function testUpdateAllRandomly(uint160 amount, uint48 expiration, uint48 nonce) public {
        // there is overflow since we increment the nonce by 1
        // we assume we will never be able to reach 2**48
        vm.assume(nonce < type(uint48).max);

        address token = address(token1);

        permit2.mockUpdateAll(from, token, spender, amount, expiration, nonce);

        uint48 nonceAfterUpdate = nonce + 1;
        uint48 timestampAfterUpdate = expiration == 0 ? uint48(block.timestamp) : expiration;

        (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, token, spender);

        assertEq(amount, amount1);
        assertEq(timestampAfterUpdate, expiration1);
        assertEq(nonceAfterUpdate, nonce1);
    }

    function testPackAndUnpack(uint160 amount, uint48 expiration, uint48 nonce) public {
        // pack some numbers
        uint256 word = Allowance.pack(amount, expiration, nonce);

        // store the raw word
        permit2.doStore(from, address(token1), spender, word);

        // load it as a packed allowance
        (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, address(token1), spender);
        assertEq(amount, amount1);
        assertEq(expiration, expiration1);
        assertEq(nonce, nonce1);

        // get the stored word
        uint256 word1 = permit2.getStore(from, address(token1), spender);
        assertEq(word, word1);
    }
}
