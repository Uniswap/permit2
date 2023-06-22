// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ISignatureTransfer} from "../../src/interfaces/ISignatureTransfer.sol";
import {PermitHash} from "../../src/libraries/PermitHash.sol";

contract MockHash {
    using PermitHash for ISignatureTransfer.PermitTransferFrom;
    using PermitHash for ISignatureTransfer.PermitBatchTransferFrom;

    function hash(ISignatureTransfer.PermitTransferFrom memory permit) external view returns (bytes32) {
        return permit.hash();
    }

    function hash(ISignatureTransfer.PermitBatchTransferFrom memory permit) external view returns (bytes32) {
        return permit.hash();
    }

    function hashWithWitness(
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeString
    ) external view returns (bytes32) {
        return permit.hashWithWitness(witness, witnessTypeString);
    }

    function hashWithWitness(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes32 witness,
        string calldata witnessTypeString
    ) external view returns (bytes32) {
        return permit.hashWithWitness(witness, witnessTypeString);
    }
}
