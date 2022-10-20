// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Vm} from "forge-std/Vm.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/draft-EIP712.sol";
import {Permit, PermitTransfer, PermitBatchTransfer} from "../../src/Permit2Utils.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Permit2} from "../../src/Permit2.sol";

contract PermitSignature {
    bytes32 public constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address token,address spender,uint160 amount,uint64 expiration,uint32 nonce,uint256 sigDeadline)"
    );

    bytes32 public constant _PERMIT_TRANSFER_TYPEHASH = keccak256(
        "PermitTransferFrom(address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(address[] tokens,address spender,uint256[] maxAmounts,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    function getPermitSignature(Vm vm, Permit memory permit, uint32 nonce, uint256 privateKey, bytes32 domainSeparator)
        internal
        returns (bytes memory sig)
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
                        permit.sigDeadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitTransferSignature(
        Vm vm,
        PermitTransfer memory permit,
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
                        permit.deadline,
                        permit.witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchSignature(
        Vm vm,
        PermitBatchTransfer memory permit,
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
                        permit.deadline,
                        permit.witness
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
        returns (Permit memory)
    {
        return Permit({
            token: token0,
            spender: address(this),
            amount: amount,
            expiration: expiration,
            nonce: nonce,
            sigDeadline: block.timestamp + 100
        });
    }

    function defaultERC20PermitTransfer(address token0, uint256 nonce) internal view returns (PermitTransfer memory) {
        return PermitTransfer({
            token: token0,
            spender: address(this),
            signedAmount: 10 ** 18,
            nonce: nonce,
            deadline: block.timestamp + 100,
            witness: 0x0
        });
    }

    function defaultERC20PermitMultiple(address[] memory tokens, uint256 nonce)
        internal
        view
        returns (PermitBatchTransfer memory)
    {
        uint256[] memory maxAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            maxAmounts[i] = 10 ** 18;
        }
        return PermitBatchTransfer({
            tokens: tokens,
            spender: address(this),
            signedAmounts: maxAmounts,
            nonce: nonce,
            deadline: block.timestamp + 100,
            witness: 0x0
        });
    }
}
