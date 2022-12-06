// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor() ERC1155() {}

    function mint(address to, uint256 id, uint256 amount) public {
        _mint(to, id, amount, "");
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return "";
    }
}
