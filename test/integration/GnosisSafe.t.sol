// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC1271} from "../../src/interfaces/IERC1271.sol";

interface GnosisSafeProxy is IERC1271 {
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
    function domainSeparator() external view returns (bytes32);
}

interface GnosisSafeProxyFactory {
    function createProxy(address singleton, bytes memory data) external returns (GnosisSafeProxy proxy);
}

contract SampleCaller {
    function checkIsValidSignature(IERC1271 target, bytes32 hash) external view returns (bytes4) {
        return target.isValidSignature(hash, "");
    }
}

contract GnosisSafeTest is Test {
    address from;
    uint256 fromPrivateKey;
    SampleCaller sampleCaller;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL"));

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);
        sampleCaller = new SampleCaller();
    }

    GnosisSafeProxyFactory gnosisSafeProxyFactory = GnosisSafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
    address singleton = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
    address compatibilityFallbackHandler = 0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;

    function testSignMessage() public {
        // deploy a safe
        address[] memory owners = new address[](1);
        owners[0] = from;
        GnosisSafeProxy safe = gnosisSafeProxyFactory.createProxy(
            singleton,
            abi.encodeCall(
                GnosisSafeProxy.setup,
                (owners, 1, address(0), "", compatibilityFallbackHandler, address(0), 0, payable(address(0)))
            )
        );

        bytes32 dataHash = keccak256("");

        // manually calculate the output of SignMessageLib#getMessageHash to avoid delegatecall issues
        bytes32 SAFE_MSG_TYPEHASH = keccak256("SafeMessage(bytes message)");
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(abi.encode(dataHash))));
        bytes32 messageHash =
            keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), safe.domainSeparator(), safeMessageHash));

        // ensure revert
        vm.expectRevert("Hash not approved");
        sampleCaller.checkIsValidSignature(safe, dataHash);

        // manually set signedMessages[dataHash] to 1
        uint256 SIGNED_MESSAGES_MAPPING_STORAGE_SLOT = 7;
        bytes32 expectedSlot = keccak256(abi.encode(messageHash, SIGNED_MESSAGES_MAPPING_STORAGE_SLOT));
        assertEq(vm.load(address(safe), expectedSlot), bytes32(0));
        vm.store(address(safe), expectedSlot, bytes32(uint256(1)));

        // test the functionality
        bytes4 magicValue = sampleCaller.checkIsValidSignature(safe, dataHash);
        assertEq(magicValue, IERC1271.isValidSignature.selector);
    }
}
