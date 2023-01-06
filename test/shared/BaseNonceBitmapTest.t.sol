// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMockPermit2} from "../mocks/MockPermit2.sol";
import {InvalidNonce} from "../../src/shared/PermitErrors.sol";

abstract contract BaseNonceBitmapTest is Test {
    IMockPermit2 permit2;

    function setUp() public virtual {}

    function testLowNonces() public {
        permit2.useUnorderedNonce(address(this), 5);
        permit2.useUnorderedNonce(address(this), 0);
        permit2.useUnorderedNonce(address(this), 1);

        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 1);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 5);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 0);
        permit2.useUnorderedNonce(address(this), 4);
    }

    function testNonceWordBoundary() public {
        permit2.useUnorderedNonce(address(this), 255);
        permit2.useUnorderedNonce(address(this), 256);

        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 255);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 256);
    }

    function testHighNonces() public {
        permit2.useUnorderedNonce(address(this), 2 ** 240);
        permit2.useUnorderedNonce(address(this), 2 ** 240 + 1);

        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 2 ** 240);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 2 ** 240 + 1);
    }

    function testInvalidateFullWord() public {
        invalidateUnorderedNonces(0, 2 ** 256 - 1);

        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 0);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 1);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 254);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 255);
        permit2.useUnorderedNonce(address(this), 256);
    }

    function testInvalidateNonzeroWord() public {
        invalidateUnorderedNonces(1, 2 ** 256 - 1);

        permit2.useUnorderedNonce(address(this), 0);
        permit2.useUnorderedNonce(address(this), 254);
        permit2.useUnorderedNonce(address(this), 255);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 256);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 511);
        permit2.useUnorderedNonce(address(this), 512);
    }

    function testUsingNonceTwiceFails(uint256 nonce) public {
        permit2.useUnorderedNonce(address(this), nonce);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), nonce);
    }

    function testUseTwoRandomNonces(uint256 first, uint256 second) public {
        permit2.useUnorderedNonce(address(this), first);
        if (first == second) {
            vm.expectRevert(InvalidNonce.selector);
            permit2.useUnorderedNonce(address(this), second);
        } else {
            permit2.useUnorderedNonce(address(this), second);
        }
    }

    function testInvalidateNoncesRandomly(uint248 wordPos, uint256 mask) public {
        invalidateUnorderedNonces(wordPos, mask);
        assertEq(mask, nonceBitmap(address(this), wordPos));
    }

    function testInvalidateTwoNoncesRandomly(uint248 wordPos, uint256 startBitmap, uint256 mask) public {
        invalidateUnorderedNonces(wordPos, startBitmap);
        assertEq(startBitmap, nonceBitmap(address(this), wordPos));

        // invalidating with the mask changes the original bitmap
        uint256 finalBitmap = startBitmap | mask;
        invalidateUnorderedNonces(wordPos, mask);
        uint256 savedBitmap = nonceBitmap(address(this), wordPos);
        assertEq(finalBitmap, savedBitmap);

        // invalidating with the same mask should do nothing
        invalidateUnorderedNonces(wordPos, mask);
        assertEq(savedBitmap, nonceBitmap(address(this), wordPos));
    }

    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) public virtual;
    function nonceBitmap(address addr, uint256 wordPos) public virtual returns (uint256);
}
