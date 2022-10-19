// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Vm} from "forge-std/Vm.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/draft-EIP712.sol";
import {Signature, Permit, PermitTransfer, SigType, PermitBatch} from "../../src/Permit2Utils.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Permit2} from "../../src/Permit2.sol";

contract PermitSignature {
    bytes32 public constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address token,address spender,uint160 amount,uint64 expiration,uint32 nonce,uint256 sigDeadline,bytes32 witness)"
    );

    bytes32 public constant _PERMIT_TRANSFER_TYPEHASH = keccak256(
        "PermitTransferFrom(uint8 sigType,address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(uint8 sigType,address[] tokens,address spender,uint256[] maxAmounts,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    function getPermitSignature(Vm vm, Permit memory permit, uint32 nonce, uint256 privateKey, bytes32 domainSeparator)
        internal
        returns (Signature memory sig)
    {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_TYPEHASH,
                        permit.token,
                        permit.spender,
                        permit.amount,
                        permit.expiration,
                        nonce,
                        permit.sigDeadline,
                        permit.witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = Signature(v, r, s);
    }

    function getPermitTransferSignature(
        Vm vm,
        PermitTransfer memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal returns (Signature memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_TRANSFER_TYPEHASH,
                        permit.sigType,
                        permit.token,
                        permit.spender,
                        permit.maxAmount,
                        permit.nonce,
                        permit.deadline,
                        permit.witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = Signature(v, r, s);
    }

    function getPermitBatchSignature(Vm vm, PermitBatch memory permit, uint256 privateKey, bytes32 domainSeparator)
        internal
        returns (Signature memory sig)
    {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TRANSFER_TYPEHASH,
                        permit.sigType,
                        keccak256(abi.encodePacked(permit.tokens)),
                        permit.spender,
                        keccak256(abi.encodePacked(permit.maxAmounts)),
                        permit.nonce,
                        permit.deadline,
                        permit.witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = Signature(v, r, s);
    }

    function defaultERC20PermitAllowance(address token0, uint160 amount, uint64 expiration)
        internal
        view
        returns (Permit memory)
    {
        return Permit({
            token: token0,
            spender: address(this),
            amount: amount,
            expiration: expiration,
            sigDeadline: block.timestamp + 100,
            witness: 0x0
        });
    }

    function defaultERC20PermitTransfer(address token0, uint256 nonce, SigType sigType)
        internal
        view
        returns (PermitTransfer memory)
    {
        return PermitTransfer({
            sigType: sigType,
            token: token0,
            spender: address(this),
            maxAmount: 10 ** 18,
            nonce: nonce,
            deadline: block.timestamp + 100,
            witness: 0x0
        });
    }

    function defaultERC20PermitMultiple(address[] memory tokens, uint256 nonce, SigType sigType)
        internal
        view
        returns (PermitBatch memory)
    {
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            maxAmounts[i] = 10 ** 18;
        }
        return PermitBatch({
            sigType: sigType,
            tokens: tokens,
            spender: address(this),
            maxAmounts: maxAmounts,
            nonce: nonce,
            deadline: block.timestamp + 100,
            witness: 0x0
        });
    }
}
