// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library AddressBuilder {
    function fill(uint256 length, address a) external pure returns (address[] memory addresses) {
        addresses = new address[](length);
        for (uint256 i = 0; i < length; ++i) {
            addresses[i] = a;
        }
    }

    function push(address[] calldata a, address b) external pure returns (address[] memory addresses) {
        addresses = new address[](a.length + 1);
        for (uint256 i = 0; i < a.length; ++i) {
            addresses[i] = a[i];
        }
        addresses[a.length] = b;
    }
}
