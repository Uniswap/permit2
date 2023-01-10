// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {MockERC721} from "../mocks/MockERC721.sol";

contract TokenProvider_ERC721 {
    uint256 public constant MINT_AMOUNT_ERC20 = 100 ** 18;
    uint256 public constant MINT_AMOUNT_ERC1155 = 100;

    uint256 public constant TRANSFER_AMOUNT_ERC20 = 30 ** 18;
    uint256 public constant TRANSFER_AMOUNT_ERC1155 = 10;

    MockERC721 _token0;
    MockERC721 _token1;

    address faucet = address(0x98765);

    function initializeERC721TestTokens() public {
        _token0 = new MockERC721("TestNFT1", "NFT1");
        _token1 = new MockERC721("TestNFT2", "NFT2");
    }

    function setERC721TestTokens(address from) public {
        // mint with id 1
        _token0.mint(from, 1);
        // mint with id 2
        _token1.mint(from, 2);
    }

    function setERC721TestTokenApprovals(Vm vm, address owner, address spender) public {
        vm.startPrank(owner);
        _token0.approve(spender, 1);
        _token1.approve(spender, 2);
        vm.stopPrank();
    }

    // function initializeERC1155TestTokens() public {
    //     token_erc1155_0 = new MockERC1155();
    //     token_erc1155_1 = new MockERC1155();
    // }

    // function setERC1155TestTokens(address from) public {
    //     // mint 10 with id 1
    //     token_erc1155_0.mint(from, 1, MINT_AMOUNT_ERC1155);
    //     // mint 10 with id 2
    //     token_erc1155_1.mint(from, 2, MINT_AMOUNT_ERC1155);
    // }

    // function setERC1155TestTokenApprovals(Vm vm, address owner, address spender) public {
    //     vm.startPrank(owner);
    //     token_erc1155_0.setApprovalForAll(spender, true);
    //     token_erc1155_1.setApprovalForAll(spender, true);
    //     vm.stopPrank();
    // }
}
