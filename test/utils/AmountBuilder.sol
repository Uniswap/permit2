// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.17;

library AmountBuilder {
    function fill(uint256 length, uint256 amount) external pure returns (uint256[] memory amounts) {
        amounts = new uint256[](length);
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = amount;
        }
    }

    function fillUInt8(uint256 length, uint8 tokenType) external pure returns (uint8[] memory tokenTypes) {
        tokenTypes = new uint8[](length);
        for (uint256 i = 0; i < length; ++i) {
            tokenTypes[i] = tokenType;
        }
    }

    function push(uint256[] calldata a, uint256 b) external pure returns (uint256[] memory amounts) {
        amounts = new uint256[](a.length + 1);
        for (uint256 i = 0; i < a.length; ++i) {
            amounts[i] = a[i];
        }
        amounts[a.length] = b;
    }

    function pushUInt8(uint8[] calldata a, uint8 b) external pure returns (uint8[] memory tokenTypes) {
        tokenTypes = new uint8[](a.length + 1);
        for (uint256 i = 0; i < a.length; ++i) {
            tokenTypes[i] = a[i];
        }
        tokenTypes[a.length] = b;
    }
}
