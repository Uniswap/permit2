// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {InvalidNonce} from "../src/Permit2Utils.sol";

contract NonceBitmapTest is Test {
    MockPermit2 permit2;

    function setUp() public {
        permit2 = new MockPermit2();
    }

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
        permit2.invalidateUnorderedNonces(0, 2 ** 256 - 1);

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
        permit2.invalidateUnorderedNonces(1, 2 ** 256 - 1);

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
}
