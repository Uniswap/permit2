// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MockInvalidDomainSep {
    function DOMAIN_SEPARATOR() public pure returns (bytes memory) {
        return bytes.concat(bytes32(uint256(1)), bytes1(uint8(1)));
    }
}
