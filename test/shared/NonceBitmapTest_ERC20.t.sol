// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {BaseNonceBitmapTest} from "./BaseNonceBitmapTest.t.sol";
import {MockPermit2} from "../mocks/MockPermit2.sol";

contract NonceBitmapTest_ERC20 is BaseNonceBitmapTest {
    function setUp() public override {
        permit2 = new MockPermit2();
    }

    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) public override {
        MockPermit2(address(permit2)).invalidateUnorderedNonces(wordPos, mask);
    }

    function nonceBitmap(address addr, uint256 wordPos) public override returns (uint256) {
        return MockPermit2(address(permit2)).nonceBitmap(addr, wordPos);
    }
}
