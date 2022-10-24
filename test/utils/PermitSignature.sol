// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/draft-EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Permit2} from "../../src/Permit2.sol";
import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../../src/interfaces/ISignatureTransfer.sol";

contract PermitSignature is Test {
    bytes32 public constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address token,address spender,uint160 amount,uint64 expiration,uint32 nonce,uint256 sigDeadline)"
    );
    bytes32 public constant _PERMIT_BATCH_TYPEHASH = keccak256(
        "Permit(address[] token,address spender,uint160[] amount,uint64[] expiration,uint32 nonce,uint256 sigDeadline)"
    );
    bytes32 public constant _PERMIT_TRANSFER_TYPEHASH =
        keccak256("PermitTransferFrom(address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline)");

    bytes32 public constant _PERMIT_BATCH_TRANSFER_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(address[] tokens,address spender,uint256[] maxAmounts,uint256 nonce,uint256 deadline)"
    );

    function getPermitSignatureRaw(IAllowanceTransfer.Permit memory permit, uint256 privateKey, bytes32 domainSeparator)
        internal
        returns (uint8 v, bytes32 r, bytes32 s)
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
                        permit.nonce,
                        permit.sigDeadline
                    )
                )
            )
        );

        (v, r, s) = vm.sign(privateKey, msgHash);
    }

    function getPermitSignature(IAllowanceTransfer.Permit memory permit, uint256 privateKey, bytes32 domainSeparator)
        internal
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);

        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchSignature(
        IAllowanceTransfer.PermitBatch memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal returns (bytes memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TYPEHASH,
                        keccak256(abi.encodePacked(permit.tokens)),
                        permit.spender,
                        keccak256(abi.encodePacked(permit.amounts)),
                        keccak256(abi.encodePacked(permit.expirations)),
                        permit.nonce,
                        permit.sigDeadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitTransferSignature(
        ISignatureTransfer.PermitTransfer memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal returns (bytes memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_TRANSFER_TYPEHASH,
                        permit.token,
                        permit.spender,
                        permit.signedAmount,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitWitnessTransferSignature(
        ISignatureTransfer.PermitTransfer memory permit,
        uint256 privateKey,
        bytes32 typehash,
        bytes32 witness,
        bytes32 domainSeparator
    ) internal returns (bytes memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        typehash,
                        permit.token,
                        permit.spender,
                        permit.signedAmount,
                        permit.nonce,
                        permit.deadline,
                        witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchTransferSignature(
        ISignatureTransfer.PermitBatchTransfer memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal returns (bytes memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TRANSFER_TYPEHASH,
                        keccak256(abi.encodePacked(permit.tokens)),
                        permit.spender,
                        keccak256(abi.encodePacked(permit.signedAmounts)),
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchWitnessSignature(
        ISignatureTransfer.PermitBatchTransfer memory permit,
        uint256 privateKey,
        bytes32 typeHash,
        bytes32 witness,
        bytes32 domainSeparator
    ) internal returns (bytes memory sig) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        typeHash,
                        keccak256(abi.encodePacked(permit.tokens)),
                        permit.spender,
                        keccak256(abi.encodePacked(permit.signedAmounts)),
                        permit.nonce,
                        permit.deadline,
                        witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function defaultERC20PermitAllowance(address token0, uint160 amount, uint64 expiration, uint32 nonce)
        internal
        view
        returns (IAllowanceTransfer.Permit memory)
    {
        return IAllowanceTransfer.Permit({
            token: token0,
            spender: address(this),
            amount: amount,
            expiration: expiration,
            nonce: nonce,
            sigDeadline: block.timestamp + 100
        });
    }

    function defaultERC20PermitBatchAllowance(address[] memory tokens, uint160 amount, uint64 expiration, uint32 nonce)
        internal
        view
        returns (IAllowanceTransfer.PermitBatch memory)
    {
        uint160[] memory maxAmounts = new uint160[](tokens.length);
        uint64[] memory expirations = new uint64[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            maxAmounts[i] = amount;
            expirations[i] = expiration;
        }
        return IAllowanceTransfer.PermitBatch({
            tokens: tokens,
            spender: address(this),
            amounts: maxAmounts,
            expirations: expirations,
            nonce: nonce,
            sigDeadline: block.timestamp + 100
        });
    }

    function defaultERC20PermitTransfer(address token0, uint256 nonce)
        internal
        view
        returns (ISignatureTransfer.PermitTransfer memory)
    {
        return ISignatureTransfer.PermitTransfer({
            token: token0,
            spender: address(this),
            signedAmount: 10 ** 18,
            nonce: nonce,
            deadline: block.timestamp + 100
        });
    }

    function defaultERC20PermitWitnessTransfer(address token0, uint256 nonce)
        internal
        view
        returns (ISignatureTransfer.PermitTransfer memory)
    {
        return ISignatureTransfer.PermitTransfer({
            token: token0,
            spender: address(this),
            signedAmount: 10 ** 18,
            nonce: nonce,
            deadline: block.timestamp + 100
        });
    }

    function defaultERC20PermitMultiple(address[] memory tokens, uint256 nonce)
        internal
        view
        returns (ISignatureTransfer.PermitBatchTransfer memory)
    {
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            maxAmounts[i] = 1 ** 18;
        }
        return ISignatureTransfer.PermitBatchTransfer({
            tokens: tokens,
            spender: address(this),
            signedAmounts: maxAmounts,
            nonce: nonce,
            deadline: block.timestamp + 100
        });
    }
}
