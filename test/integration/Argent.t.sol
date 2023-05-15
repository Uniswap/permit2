// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC1271} from "../../src/interfaces/IERC1271.sol";

interface WalletFactory {
    function owner() external returns (address);

    function addManager(address _manager) external;

    function createCounterfactualWallet(
        address _owner,
        address[] calldata _modules,
        address _guardian,
        bytes20 _salt,
        uint256 _refundAmount,
        address _refundToken,
        bytes calldata _ownerSignature,
        bytes calldata _managerSignature
    ) external returns (IERC1271 _wallet);
}

contract SampleCaller {
    function checkIsValidSignature(IERC1271 target, bytes32 hash, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        return target.isValidSignature(hash, signature);
    }
}

contract ArgentTest is Test {
    address from;
    uint256 fromPrivateKey;
    SampleCaller sampleCaller;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL"));

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);
        sampleCaller = new SampleCaller();
    }

    WalletFactory walletFactory = WalletFactory(0x536384FCd25b576265B6775F383D5ac408FF9dB7);
    address argentModule = 0x9D58779365B067D5D3fCc6e92d237aCd06F1e6a1;

    function testIsValidSignature() public {
        // deploy an argent wallet
        address[] memory _modules = new address[](1);
        _modules[0] = argentModule;
        vm.prank(walletFactory.owner());
        walletFactory.addManager(address(1));
        vm.prank(address(1));
        IERC1271 wallet =
            walletFactory.createCounterfactualWallet(from, _modules, address(1), bytes20(0), 0, address(0), "", "");

        // test the functionality
        bytes32 dataHash = keccak256("");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromPrivateKey, dataHash);
        bytes4 magicValue = sampleCaller.checkIsValidSignature(wallet, dataHash, bytes.concat(r, s, bytes1(v)));
        assertEq(magicValue, IERC1271.isValidSignature.selector);
    }
}
