// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit2} from "../src/Permit2.sol";

// forge test --match-contract EIP712
contract EIP712Test is Test {
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 private constant NAME_HASH = keccak256("Permit2");

    Permit2 permit2;

    function setUp() public {
        permit2 = new Permit2();
    }

    function testDomainSeparator() public {
        bytes32 expectedDomainSeparator = keccak256(abi.encode(TYPE_HASH, NAME_HASH, block.chainid, address(permit2)));

        assertEq(permit2.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    function testDomainSeparatorAfterFork() public {
        bytes32 beginningSeparator = permit2.DOMAIN_SEPARATOR();
        uint256 newChainId = block.chainid + 1;
        vm.chainId(newChainId);
        assertTrue(permit2.DOMAIN_SEPARATOR() != beginningSeparator);

        bytes32 expectedDomainSeparator = keccak256(abi.encode(TYPE_HASH, NAME_HASH, newChainId, address(permit2)));
        assertEq(permit2.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }
}
