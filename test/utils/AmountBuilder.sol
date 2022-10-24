// SPDX-License-Identifier: MIT
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

    function fillUInt160(uint256 length, uint160 amount) external pure returns (uint160[] memory amounts) {
        amounts = new uint160[](length);
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = amount;
        }
    }

    function fillUInt64(uint256 length, uint64 exp) external pure returns (uint64[] memory exps) {
        exps = new uint64[](length);
        for (uint256 i = 0; i < length; ++i) {
            exps[i] = exp;
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
