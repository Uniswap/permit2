// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";

/// @notice utilities for hashing permit structs
library PermitHash {
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

    string public constant _PERMIT_TRANSFER_WITNESS_TYPEHASH_STUB =
        "PermitWitnessTransferFrom(address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline,";

    function hash(IAllowanceTransfer.Permit calldata permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                permit.token,
                permit.spender,
                permit.amount,
                permit.expiration,
                permit.nonce,
                permit.sigDeadline
            )
        );
    }

    function hash(IAllowanceTransfer.PermitBatch calldata permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _PERMIT_BATCH_TYPEHASH,
                keccak256(abi.encodePacked(permit.tokens)),
                permit.spender,
                keccak256(abi.encodePacked(permit.amounts)),
                keccak256(abi.encodePacked(permit.expirations)),
                permit.nonce,
                permit.sigDeadline
            )
        );
    }

    function hash(ISignatureTransfer.PermitTransfer calldata permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _PERMIT_TRANSFER_TYPEHASH,
                permit.token,
                permit.spender,
                permit.signedAmount,
                permit.nonce,
                permit.deadline
            )
        );
    }

    function hash(ISignatureTransfer.PermitBatchTransfer calldata permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _PERMIT_BATCH_TRANSFER_TYPEHASH,
                keccak256(abi.encodePacked(permit.tokens)),
                permit.spender,
                keccak256(abi.encodePacked(permit.signedAmounts)),
                permit.nonce,
                permit.deadline
            )
        );
    }

    function hashWithWitness(
        ISignatureTransfer.PermitTransfer calldata permit,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType
    ) internal pure returns (bytes32) {
        bytes32 typeHash = keccak256(
            abi.encodePacked(_PERMIT_TRANSFER_WITNESS_TYPEHASH_STUB, witnessTypeName, " witness)", witnessType)
        );

        return keccak256(
            abi.encode(
                typeHash, permit.token, permit.spender, permit.signedAmount, permit.nonce, permit.deadline, witness
            )
        );
    }
}
