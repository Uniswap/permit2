// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/console2.sol";

library AllowanceMath {
    // 160    | 64        | 32
    // amount | timestamp | nonce

    function unpack(uint256 word) public pure returns (uint160 amount, uint64 timestamp, uint32 nonce) {
        nonce = uint32(word & 0xFFFFFFFF);
        timestamp = uint64((word >> 32) & 0xFFFFFFFFFFFFFFFF);
        amount = uint160(word >> 96);
    }

    function pack(uint160 amount, uint64 timestamp, uint32 nonce) public pure returns (uint256 word) {
        word = (uint256(amount) << 96);
        word = word | (uint256(timestamp) << 32) | (uint256(nonce));
    }

    function nonce(uint256 word) public pure returns (uint32) {
        return uint32(word & 0xFFFFFFFF);
    }

    function amount(uint256 word) public pure returns (uint160) {
        return uint160(word >> 96);
    }

    function timestamp(uint256 word) public pure returns (uint160) {
        return uint64((word >> 32) & 0xFFFFFFFFFFFFFFFF);
    }

    // pure
    function setAmount(uint256 word, uint160 amount) public returns (uint256) {
        console2.log(word);
        uint256 cleared = (word & 0xFFFFFFFFFFFFFFFFFFFFFFFF);
        console2.log(cleared | (uint256(amount) << 96));
        return cleared | (uint256(amount) << 96);
    }
}
