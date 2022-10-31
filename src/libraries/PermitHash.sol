// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";

library PermitHash {
    bytes32 public constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address token,address spender,uint160 amount,uint64 expiration,uint32 nonce,uint256 sigDeadline)"
    );

    bytes32 public constant _PERMIT_BATCH_TYPEHASH = keccak256(
        "PermitBatch(address[] tokens,address spender,uint160[] amounts,uint64[] expirations,uint32 nonce,uint256 sigDeadline)"
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

    function hash(IAllowanceTransfer.Permit memory permit) internal pure returns (bytes32 result) {
        bytes32 typeHash = _PERMIT_TYPEHASH;

        assembly {
            // flat structs in memory are already abi-encoded
            // so we overwrite the slot before with the typehash
            // and replace the value as we found it
            let memPtr := sub(permit, 0x20)
            // save the original value of the slot before permit
            let prevValue := mload(memPtr)
            // overwrite it with the typeHash
            mstore(memPtr, typeHash)

            result := keccak256(memPtr, 0xe0)
            // restore the original value of the slot before permit
            mstore(memPtr, prevValue)
        }
    }

    function hash(IAllowanceTransfer.PermitBatch memory permit) internal pure returns (bytes32 result) {
        bytes32 typeHash = _PERMIT_BATCH_TYPEHASH;

        assembly {
            // prepare hashes of subarrays first
            // first slot is tokens, and the struct format is just an offset to the actual array
            let offset := mload(permit)
            // first slot of the actual array is the size
            // size of all 3 arrays is the same, so we can save and reuse
            let permitSize := mul(mload(offset), 0x20)

            // arrays are already in abi.encodePacked format inside struct
            // so we can directly hash with a pointer and the correct size
            // get hash of the token array
            let tokenHash := keccak256(add(offset, 0x20), permitSize)
            // get hash of the amounts array
            // amounts array is directly after the end of the tokens array
            offset := add(offset, add(permitSize, 0x40))
            let amountHash := keccak256(offset, permitSize)
            // get hash of the expiration array
            // expirations array is directly after the end of the amounts array
            offset := add(offset, add(permitSize, 0x20))
            let expirationHash := keccak256(offset, permitSize)

            // load freemem ptr
            let memPtr := mload(0x40)
            // store abi encoded permit data and hash
            mstore(memPtr, typeHash)
            mstore(add(memPtr, 0x20), tokenHash)
            // load spender and store
            mstore(add(memPtr, 0x40), mload(add(permit, 0x20)))
            mstore(add(memPtr, 0x60), amountHash)
            mstore(add(memPtr, 0x80), expirationHash)
            // load nonce and store
            mstore(add(memPtr, 0xa0), mload(add(permit, 0x80)))
            // load sigDeadline and store
            mstore(add(memPtr, 0xc0), mload(add(permit, 0xa0)))
            result := keccak256(memPtr, 0xe0)
        }
    }

    function hash(ISignatureTransfer.PermitTransferFrom memory permit) internal pure returns (bytes32 result) {
        bytes32 typeHash = _PERMIT_TRANSFER_FROM_TYPEHASH;

        assembly {
            // flat structs in memory are already abi-encoded
            // so we overwrite the slot before with the typehash
            // and replace the value as we found it
            let memPtr := sub(permit, 0x20)
            // save the original value of the slot before permit
            let prevValue := mload(memPtr)
            // overwrite it with the typeHash
            mstore(memPtr, typeHash)

            result := keccak256(memPtr, 0xc0)
            // restore the original value of the slot before permit
            mstore(memPtr, prevValue)
        }
    }

    function hash(ISignatureTransfer.PermitBatchTransferFrom memory permit) internal pure returns (bytes32 result) {
        bytes32 typeHash = _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH;

        assembly {
            // prepare hashes of subarrays first
            // first slot is tokens, and the struct format is just an offset to the actual array
            let offset := mload(permit)
            // first slot of the actual array is the size
            // size of all 3 arrays is the same, so we can save and reuse
            let permitSize := mul(mload(offset), 0x20)

            // arrays are already in abi.encodePacked format inside struct
            // so we can directly hash with a pointer and the correct size
            // get hash of the token array
            let tokenHash := keccak256(add(offset, 0x20), permitSize)
            // get hash of the signedAmounts array
            // amounts array is directly after the end of the tokens array
            let amountHash := keccak256(add(offset, add(permitSize, 0x40)), permitSize)

            // load freemem ptr
            let memPtr := mload(0x40)
            // store abi encoded permit data and hash
            mstore(memPtr, typeHash)
            mstore(add(memPtr, 0x20), tokenHash)
            // load spender and store
            mstore(add(memPtr, 0x40), mload(add(permit, 0x20)))
            mstore(add(memPtr, 0x60), amountHash)
            // load nonce and store
            mstore(add(memPtr, 0x80), mload(add(permit, 0x60)))
            // load deadline and store
            mstore(add(memPtr, 0xa0), mload(add(permit, 0x80)))
            result := keccak256(memPtr, 0xc0)
        }
    }

    function hashWithWitness(
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType
    ) internal pure returns (bytes32 result) {
        bytes32 typeHash = keccak256(
            abi.encodePacked(_PERMIT_TRANSFER_FROM_WITNESS_TYPEHASH_STUB, witnessTypeName, " witness)", witnessType)
        );

        assembly {
            // flat structs in memory are already abi-encoded
            // so we overwrite the slot before with the typehash
            // and the slot after with the witness
            // and replace the values as we found them
            let memPtr := sub(permit, 0x20)
            // save the original value of the slot before permit
            let prevValueBefore := mload(memPtr)
            let prevValueAfter := mload(add(memPtr, 0xc0))
            // overwrite the slot before with the typeHash
            mstore(memPtr, typeHash)
            // overwrite the slot after with the witness
            mstore(add(memPtr, 0xc0), witness)

            result := keccak256(memPtr, 0xe0)
            // restore the original value of the slot before permit
            mstore(memPtr, prevValueBefore)
            // restore the original value of the slot after permit
            mstore(add(memPtr, 0xc0), prevValueAfter)
        }
    }

    function hashWithWitness(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType
    ) internal pure returns (bytes32 result) {
        bytes32 typeHash = keccak256(
            abi.encodePacked(
                _PERMIT_BATCH_WITNESS_TRANSFER_FROM_TYPEHASH_STUB, witnessTypeName, " witness)", witnessType
            )
        );

        assembly {
            // prepare hashes of subarrays first
            // first slot is tokens, and the struct format is just an offset to the actual array
            let offset := mload(permit)
            // first slot of the actual array is the size
            // size of all 3 arrays is the same, so we can save and reuse
            let permitSize := mul(mload(offset), 0x20)

            // arrays are already in abi.encodePacked format inside struct
            // so we can directly hash with a pointer and the correct size
            // get hash of the token array
            let tokenHash := keccak256(add(offset, 0x20), permitSize)
            // get hash of the signedAmounts array
            // amounts array is directly after the end of the tokens array
            let amountHash := keccak256(add(offset, add(permitSize, 0x40)), permitSize)

            // load freemem ptr
            let memPtr := mload(0x40)
            // store abi encoded permit data and hash
            mstore(memPtr, typeHash)
            mstore(add(memPtr, 0x20), tokenHash)
            // load spender and store
            mstore(add(memPtr, 0x40), mload(add(permit, 0x20)))
            mstore(add(memPtr, 0x60), amountHash)
            // load nonce and store
            mstore(add(memPtr, 0x80), mload(add(permit, 0x60)))
            // load deadline and store
            mstore(add(memPtr, 0xa0), mload(add(permit, 0x80)))
            mstore(add(memPtr, 0xc0), witness)
            result := keccak256(memPtr, 0xe0)
        }
    }
}
