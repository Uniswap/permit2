// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solmate/src/tokens/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }

    function tokenURI(uint256) public view virtual override returns (string memory) {
        return "";
    }
}
