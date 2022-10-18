// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";

contract TokenProvider {
    uint256 public constant MINT_AMOUNT_ERC20 = 60 ** 18;
    uint256 public constant MINT_AMOUNT_ERC1155 = 10;

    MockERC20 token0;
    MockERC20 token1;
    MockERC721 nft1;
    MockERC721 nft2;
    MockERC1155 nft3;
    MockERC1155 nft4;

    // TODO faucent for NFTs

    function initializeTokens() public {
        token0 = new MockERC20("Test0", "TEST0", 18);
        token1 = new MockERC20("Test1", "TEST1", 18);
        // nft1 = new MockERC721("TestNFT1", "NFT1");
        // nft2 = new MockERC721("TestNFT2", "NFT2");
        nft3 = new MockERC1155();
        nft4 = new MockERC1155();
    }

    function setTestTokens(address from) public {
        token0.mint(from, MINT_AMOUNT_ERC20);
        token1.mint(from, MINT_AMOUNT_ERC20);
        // // mint with id 1
        // nft1.mint(from, 1);
        // // mint with id 2
        // nft2.mint(from, 2);
        // mint 10 with id 1
        nft3.mint(from, 1, MINT_AMOUNT_ERC1155);
        // mint 10 with id 2
        nft4.mint(from, 2, MINT_AMOUNT_ERC1155);
    }

    function setTestTokenApprovals(Vm vm, address owner, address spender) public {
        vm.startPrank(owner);
        token0.approve(spender, type(uint256).max);
        token1.approve(spender, type(uint256).max);
        // nft1.approve(spender, 1);
        // nft2.approve(spender, 2);
        nft3.setApprovalForAll(spender, true);
        nft4.setApprovalForAll(spender, true);
        vm.stopPrank();
    }
}
