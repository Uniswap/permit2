// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";

contract TokenProvider {
    uint256 public constant MINT_AMOUNT_ERC20 = 100 ** 18;
    uint256 public constant MINT_AMOUNT_ERC1155 = 100;

    uint256 public constant TRANSFER_AMOUNT_ERC20 = 30 ** 18;
    uint256 public constant TRANSFER_AMOUNT_ERC1155 = 10;

    MockERC20 token0;
    MockERC20 token1;
    mapping(address => MockERC721[]) public nfts;
    MockERC1155 nft3;
    MockERC1155 nft4;

    address faucet = address(0x98765);

    error MintMoreNFTs();

    function initializeERC20Tokens() public {
        token0 = new MockERC20("Test0", "TEST0", 18);
        token1 = new MockERC20("Test1", "TEST1", 18);
    }

    function setERC20TestTokens(address from) public {
        token0.mint(from, MINT_AMOUNT_ERC20);
        token1.mint(from, MINT_AMOUNT_ERC20);
    }

    function setERC20TestTokenApprovals(Vm vm, address owner, address spender) public {
        vm.startPrank(owner);
        token0.approve(spender, type(uint256).max);
        token1.approve(spender, type(uint256).max);
        vm.stopPrank();
    }

    function initializeForOwner(uint256 amount, address owner) public {
        nfts[owner] = new MockERC721[](amount);
    }

    function getNFT(address owner, uint256 index) public view returns (MockERC721) {
        return nfts[owner][index];
    }

    function initializeERC721TokensAndApprove(Vm vm, address owner, address spender, uint256 amount) public {
        if (amount > nfts[owner].length) revert MintMoreNFTs();
        string memory base = "TestNFT";
        for (uint256 i = 0; i < amount; i++) {
            string memory name = string(abi.encodePacked(base, i));
            MockERC721 nft = new MockERC721(name, "NFT");
            nft.mint(owner, i);
            vm.prank(owner);
            nft.approve(spender, i);
            nfts[owner][i] = nft;
        }
    }
}
