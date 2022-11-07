// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";

library PermitHash {
    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint64 expiration,uint32 nonce)");

    bytes32 public constant _PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint64 expiration,uint32 nonce)"
    );

    bytes32 public constant _PERMIT_BATCH_TYPEHASH = keccak256(
        "PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint64 expiration,uint32 nonce)"
    );

    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(address token,address spender,uint256 signedAmount,uint256 nonce,uint256 deadline)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(address[] tokens,address spender,uint256[] signedAmounts,uint256 nonce,uint256 deadline)"
    );

    string public constant _PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB =
        "PermitWitnessTransferFrom(address token,address spender,uint256 signedAmount,uint256 nonce,uint256 deadline,";

    string public constant _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB =
        "PermitBatchWitnessTransferFrom(address[] tokens,address spender,uint256[] signedAmounts,uint256 nonce,uint256 deadline,";

    function hash(IAllowanceTransfer.PermitSingle memory permitSingle) internal pure returns (bytes32) {
        bytes32 permitHash = _hashPermitDetails(permitSingle.details);
        return
            keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permitSingle.spender, permitSingle.sigDeadline));
    }

    function hash(IAllowanceTransfer.PermitBatch memory permitBatch) internal pure returns (bytes32) {
        uint256 numPermits = permitBatch.details.length;
        bytes32[] memory permitHashes = new bytes32[](numPermits);
        for (uint256 i = 0; i < numPermits; ++i) {
            permitHashes[i] = _hashPermitDetails(permitBatch.details[i]);
        }
        return keccak256(
            abi.encode(
                _PERMIT_BATCH_TYPEHASH,
                keccak256(abi.encodePacked(permitHashes)),
                permitBatch.spender,
                permitBatch.sigDeadline
            )
        );
    }

    function hash(ISignatureTransfer.PermitTransferFrom memory permit) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _PERMIT_TRANSFER_FROM_TYPEHASH,
                permit.token,
                msg.sender,
                permit.signedAmount,
                permit.nonce,
                permit.deadline
            )
        );
    }

    function hash(ISignatureTransfer.PermitBatchTransferFrom memory permit) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                keccak256(abi.encodePacked(permit.tokens)),
                msg.sender,
                keccak256(abi.encodePacked(permit.signedAmounts)),
                permit.nonce,
                permit.deadline
            )
        );
    }

    function hashWithWitness(
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType
    ) internal view returns (bytes32) {
        bytes32 typeHash = keccak256(
            abi.encodePacked(_PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeName, " witness)", witnessType)
        );

        return keccak256(
            abi.encode(typeHash, permit.token, msg.sender, permit.signedAmount, permit.nonce, permit.deadline, witness)
        );
    }

    function hashWithWitness(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType
    ) internal view returns (bytes32) {
        bytes32 typeHash = keccak256(
            abi.encodePacked(
                _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB, witnessTypeName, " witness)", witnessType
            )
        );

        return keccak256(
            abi.encode(
                typeHash,
                keccak256(abi.encodePacked(permit.tokens)),
                msg.sender,
                keccak256(abi.encodePacked(permit.signedAmounts)),
                permit.nonce,
                permit.deadline,
                witness
            )
        );
    }

    function _hashPermitDetails(IAllowanceTransfer.PermitDetails memory details) private pure returns (bytes32) {
        return keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, details));
    }
}
