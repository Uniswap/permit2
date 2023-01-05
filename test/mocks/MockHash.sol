// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ISignatureTransfer} from "../../src/ERC20/interfaces/ISignatureTransfer.sol";
import {IAllowanceTransfer} from "../../src/ERC20/interfaces/IAllowanceTransfer.sol";
import {PermitHash} from "../../src/ERC20/libraries/PermitHash.sol";

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
