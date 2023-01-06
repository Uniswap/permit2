// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {BaseNonceBitmapTest} from "./BaseNonceBitmapTest.t.sol";
import {MockPermit2_ERC721} from "../mocks/MockPermit2_ERC721.sol";

contract NonceBitmapTest_ERC721 is BaseNonceBitmapTest {
    function setUp() public override {
        permit2 = new MockPermit2_ERC721();
    }
}
