// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.17;

// import "forge-std/Test.sol";
// import {BaseNonceBitmapTest} from "./BaseNonceBitmapTest.t.sol";
// import {MockPermit2ERC721} from "../mocks/MockPermit2ERC721.sol";

// contract NonceBitmapTestERC721 is BaseNonceBitmapTest {
//     function setUp() public override {
//         permit2 = new MockPermit2ERC721();
//     }

//     function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) public override {
//         MockPermit2ERC721(address(permit2)).invalidateUnorderedNonces(wordPos, mask);
//     }

//     function nonceBitmap(address addr, uint256 wordPos) public override returns (uint256) {
//         return MockPermit2ERC721(address(permit2)).nonceBitmap(addr, wordPos);
//     }
// }
