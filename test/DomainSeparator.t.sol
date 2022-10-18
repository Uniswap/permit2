pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {Permit2} from "../src/Permit2.sol";

// forge test --match-contract DomainSeparator
contract DomainSeparatorTest is Test {
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant NAME_HASH = keccak256("Permit2");
    bytes32 private constant VERSION_HASH = keccak256("1");

    Permit2 permit2;

    function setUp() public {
        permit2 = new Permit2();
    }

    function testDomainSeparator() public {
        bytes32 expectedDomainSeparator =
            keccak256(abi.encode(TYPE_HASH, NAME_HASH, VERSION_HASH, block.chainid, address(permit2)));

        assertEq(permit2.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    function testDomainSeparatorAfterFork() public {
        bytes32 beginningSeparator = permit2.DOMAIN_SEPARATOR();
        uint256 newChainId = block.chainid + 1;
        vm.chainId(newChainId);
        assertTrue(permit2.DOMAIN_SEPARATOR() != beginningSeparator);

        bytes32 expectedDomainSeparator =
            keccak256(abi.encode(TYPE_HASH, NAME_HASH, VERSION_HASH, newChainId, address(permit2)));
        assertEq(permit2.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }
}
