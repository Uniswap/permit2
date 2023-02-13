// // // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.18;

// import "forge-std/Test.sol";
// import "../mocks/MockPermit2ERC721.sol";
// import {BaseAllowanceUnitTest} from "./BaseAllowanceUnitTest.sol";
// import {TokenProvider} from "../utils/TokenProvider.sol";

// contract AllowanceUnitTestERC721 is BaseAllowanceUnitTest {
//     function setUp() public override {
//         permit2 = new MockPermit2ERC721();
//         initializeForOwner(1, from);
//         initializeERC721TokensAndApprove(vm, from, address(permit2), 1);
//     }

//     function allowance(address from, address token, address spender, uint256 tokenId)
//         public
//         view
//         override
//         returns (uint160, uint48, uint48)
//     {
//         (address spender1, uint48 expiration1, uint48 nonce1) =
//             MockPermit2ERC721(address(permit2)).allowance(from, token, tokenId);
//         return (uint160(spender1), expiration1, nonce1);
//     }

//     function token() public view override returns (address) {
//         return address(getNFT(from, 0));
//     }
// }
