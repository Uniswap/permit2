// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";
import {SignatureExpired, InvalidNonce} from "./PermitErrors.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {PermitHash} from "./libraries/PermitHash.sol";
import {EIP712} from "./EIP712.sol";

contract SignatureTransfer is ISignatureTransfer, EIP712 {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;
    using PermitHash for PermitTransferFrom;
    using PermitHash for PermitBatchTransferFrom;

    /// @inheritdoc ISignatureTransfer
    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

    /// @inheritdoc ISignatureTransfer
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        address owner,
        address to,
        uint256 requestedAmount,
        bytes calldata signature
    ) external {
        _permitTransferFrom(permit, permit.hash(), owner, to, requestedAmount, signature);
    }

    /// @inheritdoc ISignatureTransfer
    function permitWitnessTransferFrom(
        PermitTransferFrom memory permit,
        address owner,
        address to,
        uint256 requestedAmount,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType,
        bytes calldata signature
    ) external {
        _permitTransferFrom(
            permit, permit.hashWithWitness(witness, witnessTypeName, witnessType), owner, to, requestedAmount, signature
        );
    }

    /// @notice Transfers a token using a signed permit message.
    /// @dev If to is the zero address, the tokens are sent to the spender.
    /// @param permit The permit data signed over by the owner
    /// @param dataHash The EIP-712 hash of permit data to include when checking signature
    /// @param owner The owner of the tokens to transfer
    /// @param to The recipient of the tokens
    /// @param requestedAmount The amount of tokens to transfer
    /// @param signature The signature to verify
    function _permitTransferFrom(
        PermitTransferFrom memory permit,
        bytes32 dataHash,
        address owner,
        address to,
        uint256 requestedAmount,
        bytes calldata signature
    ) internal {
        if (block.timestamp > permit.deadline) revert SignatureExpired();
        if (requestedAmount > permit.permitted.amount) revert InvalidAmount();
        _useUnorderedNonce(owner, permit.nonce);

        signature.verify(_hashTypedData(dataHash), owner);

        ERC20(permit.permitted.token).safeTransferFrom(owner, to, requestedAmount);
    }

    /// @inheritdoc ISignatureTransfer
    function permitBatchTransferFrom(
        PermitBatchTransferFrom memory permit,
        address owner,
        SignatureTransferDetails[] calldata transferDetails,
        bytes calldata signature
    ) external {
        _permitBatchTransferFrom(permit, permit.hash(), owner, transferDetails, signature);
    }

    /// @inheritdoc ISignatureTransfer
    function permitBatchWitnessTransferFrom(
        PermitBatchTransferFrom memory permit,
        address owner,
        SignatureTransferDetails[] calldata transferDetails,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType,
        bytes calldata signature
    ) external {
        _permitBatchTransferFrom(
            permit, permit.hashWithWitness(witness, witnessTypeName, witnessType), owner, transferDetails, signature
        );
    }

    /// @notice Transfers tokens using a signed permit messages
    /// @dev If to is the zero address, the tokens are sent to the spender
    /// @param permit The permit data signed over by the owner
    /// @param dataHash The EIP-712 hash of permit data to include when checking signature
    /// @param owner The owner of the tokens to transfer
    /// @param signature The signature to verify
    function _permitBatchTransferFrom(
        PermitBatchTransferFrom memory permit,
        bytes32 dataHash,
        address owner,
        SignatureTransferDetails[] calldata transferDetails,
        bytes calldata signature
    ) internal {
        uint256 numPermitted = permit.permitted.length;

        if (block.timestamp > permit.deadline) revert SignatureExpired();
        if (numPermitted != transferDetails.length) revert LengthMismatch();

        _useUnorderedNonce(owner, permit.nonce);
        signature.verify(_hashTypedData(dataHash), owner);

        unchecked {
            for (uint256 i = 0; i < numPermitted; ++i) {
                TokenPermissions memory permitted = permit.permitted[i];
                uint256 requestedAmount = transferDetails[i].requestedAmount;

                if (requestedAmount > permitted.amount) revert InvalidAmount();

                ERC20(permitted.token).safeTransferFrom(owner, transferDetails[i].to, requestedAmount);
            }
        }
    }

    /// @inheritdoc ISignatureTransfer
    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external {
        nonceBitmap[msg.sender][wordPos] |= mask;

        emit UnorderedNonceInvalidation(msg.sender, wordPos, mask);
    }

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces
    /// @param nonce The nonce to get the associated word and bit positions
    /// @return wordPos The word position or index into the nonceBitmap
    /// @return bitPos The bit position
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap
    /// @dev The last 8 bits of the nonce value is the position of the bit in the bitmap
    function bitmapPositions(uint256 nonce) private pure returns (uint256 wordPos, uint256 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce & 255);
    }

    /// @notice Checks whether a nonce is taken and sets the bit at the bit position in the bitmap at the word position
    /// @param from The address to use the nonce at
    /// @param nonce The nonce to spend
    function _useUnorderedNonce(address from, uint256 nonce) internal {
        (uint256 wordPos, uint256 bitPos) = bitmapPositions(nonce);
        uint256 bitmap = nonceBitmap[from][wordPos];

        if ((bitmap >> bitPos) & 1 == 1) revert InvalidNonce();

        nonceBitmap[from][wordPos] = bitmap | (1 << bitPos);
    }
}
