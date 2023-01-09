// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../mocks/IMockPermit2.sol";
import {TokenProvider} from "../utils/TokenProvider.sol";

abstract contract BaseAllowanceUnitTest is Test, TokenProvider {
    IMockPermit2 permit2;

    address from = address(0xBEEE);
    address spender = address(0xBBBB);

    function setUp() public virtual {}

    function allowance(address from, address token, address spender) public virtual returns (uint160, uint48, uint48);

    function token() public virtual returns (address);

    function testUpdateAmountExpirationRandomly(uint160 amount, uint48 expiration) public {
        address token = token();

        (,, uint48 nonce) = allowance(from, token, spender);

        permit2.mockUpdateSome(from, token, spender, amount, expiration);

        uint48 timestampAfterUpdate = expiration == 0 ? uint48(block.timestamp) : expiration;

        (uint160 amount1, uint48 expiration1, uint48 nonce1) = allowance(from, token, spender);
        assertEq(amount, amount1);
        assertEq(timestampAfterUpdate, expiration1);
        /// nonce shouldnt change
        assertEq(nonce, nonce1);
    }

    function testUpdateAllRandomly(uint160 amount, uint48 expiration, uint48 nonce) public {
        // there is overflow since we increment the nonce by 1
        // we assume we will never be able to reach 2**48
        vm.assume(nonce < type(uint48).max);

        address token = token();

        permit2.mockUpdateAll(from, token, spender, amount, expiration, nonce);

        uint48 nonceAfterUpdate = nonce + 1;
        uint48 timestampAfterUpdate = expiration == 0 ? uint48(block.timestamp) : expiration;

        (uint160 amount1, uint48 expiration1, uint48 nonce1) = allowance(from, token, spender);

        assertEq(amount, amount1);
        assertEq(timestampAfterUpdate, expiration1);
        assertEq(nonceAfterUpdate, nonce1);
    }

    function testPackAndUnpack(uint160 amount, uint48 expiration, uint48 nonce) public {
        // pack some numbers
        uint256 word = Allowance.pack(amount, expiration, nonce);
        address token = token();
        // store the raw word
        permit2.doStore(from, token, spender, word);

        // load it as a packed allowance
        (uint160 amount1, uint48 expiration1, uint48 nonce1) = allowance(from, token, spender);
        assertEq(amount, amount1);
        assertEq(expiration, expiration1);
        assertEq(nonce, nonce1);

        // get the stored word
        uint256 word1 = permit2.getStore(from, token, spender);
        assertEq(word, word1);
    }
}
