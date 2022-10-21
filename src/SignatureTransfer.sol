// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {
    PermitTransfer,
    PermitBatchTransfer,
    PermitWitnessTransfer,
    InvalidNonce,
    LengthMismatch,
    NotSpender,
    InvalidAmount,
    SignatureExpired,
    SignedDetailsLengthMismatch,
    AmountsLengthMismatch,
    RecipientLengthMismatch
} from "./Permit2Utils.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {DomainSeparator} from "./DomainSeparator.sol";

contract SignatureTransfer is DomainSeparator {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;

    bytes32 public constant _PERMIT_TRANSFER_TYPEHASH =
        keccak256("PermitTransferFrom(address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline)");

    bytes32 public constant _PERMIT_BATCH_TRANSFER_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(address[] tokens,address spender,uint256[] maxAmounts,uint256 nonce,uint256 deadline)"
    );

    string public constant _PERMIT_TRANSFER_WITNESS_TYPEHASH_STUB =
        "PermitWitnessTransferFrom(address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline,";

    event InvalidateUnorderedNonces(address indexed owner, uint248 word, uint256 mask);

    mapping(address => mapping(uint248 => uint256)) public nonceBitmap;

    /// @notice Transfers a token using a signed permit message.
    /// @dev If to is the zero address, the tokens are sent to the spender.
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param to The recipient of the tokens
    /// @param requestedAmount The amount of tokens to transfer
    /// @param signature The signature to verify
    function permitTransferFrom(
        PermitTransfer calldata permit,
        address owner,
        address to,
        uint256 requestedAmount,
        bytes calldata signature
    ) external {
        _validatePermit(permit.spender, permit.deadline);
        if (requestedAmount > permit.signedAmount) {
            revert InvalidAmount();
        }

        _useUnorderedNonce(owner, permit.nonce);

        signature.verify(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
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
            ),
            owner
        );

        // send to spender if the inputted to address is 0
        address recipient = to == address(0) ? permit.spender : to;
        ERC20(permit.token).safeTransferFrom(owner, recipient, requestedAmount);
    }

    /// @notice Transfers a token using a signed permit message.
    /// @notice Includes extra data provided by the caller to verify signature over.
    /// @dev If to is the zero address, the tokens are sent to the spender.
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param to The recipient of the tokens
    /// @param requestedAmount The amount of tokens to transfer
    /// @param witnessTypeName The name of the witness type
    /// @param witnessType The EIP-712 type definition for the witness type
    /// @param signature The signature to verify
    function permitWitnessTransferFrom(
        PermitWitnessTransfer calldata permit,
        address owner,
        address to,
        uint256 requestedAmount,
        string calldata witnessTypeName,
        string calldata witnessType,
        bytes calldata signature
    ) public {
        _validatePermit(permit.spender, permit.deadline);

        if (requestedAmount > permit.signedAmount) {
            revert InvalidAmount();
        }

        bytes32 typeHash = keccak256(
            abi.encodePacked(_PERMIT_TRANSFER_WITNESS_TYPEHASH_STUB, witnessTypeName, " witness)", witnessType)
        );

        _useUnorderedNonce(owner, permit.nonce);

        signature.verify(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            typeHash,
                            permit.token,
                            permit.spender,
                            permit.signedAmount,
                            permit.nonce,
                            permit.deadline,
                            permit.witness
                        )
                    )
                )
            ),
            owner
        );

        // send to spender if the inputted to address is 0
        address recipient = to == address(0) ? permit.spender : to;
        ERC20(permit.token).safeTransferFrom(owner, recipient, requestedAmount);
    }

    /// @notice Transfers tokens using a signed permit message.
    /// @dev If to is the zero address, the tokens are sent to the spender.
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param to The recipients of the tokens
    /// @param requestedAmounts The amount of tokens to transfer
    /// @param signature The signature to verify
    function permitBatchTransferFrom(
        PermitBatchTransfer calldata permit,
        address owner,
        address[] calldata to,
        uint256[] calldata requestedAmounts,
        bytes calldata signature
    ) external {
        _validatePermit(permit.spender, permit.deadline);
        _validateInputLengths(permit.tokens.length, to.length, permit.signedAmounts.length, requestedAmounts.length);
        unchecked {
            for (uint256 i = 0; i < permit.tokens.length; ++i) {
                if (requestedAmounts[i] > permit.signedAmounts[i]) {
                    revert InvalidAmount();
                }
            }
        }

        _useUnorderedNonce(owner, permit.nonce);

        signature.verify(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
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
            ),
            owner
        );

        unchecked {
            for (uint256 i = 0; i < permit.tokens.length; ++i) {
                ERC20(permit.tokens[i]).transferFrom(owner, to[i], requestedAmounts[i]);
            }
        }
    }

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces.
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap.
    /// The last 8 bits of the nonce value is the position of the bit in the bitmap.
    function bitmapPositions(uint256 nonce) public pure returns (uint248 wordPos, uint8 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce & 255);
    }

    /// @notice Invalidates the bits specified in `mask` for the bitmap at `wordPos`.
    function invalidateUnorderedNonces(uint248 wordPos, uint256 mask) external {
        nonceBitmap[msg.sender][wordPos] |= mask;
        emit InvalidateUnorderedNonces(msg.sender, wordPos, mask);
    }

    /// @notice Checks whether a nonce is taken. Then sets the bit at the bitPos in the bitmap at the wordPos.
    function _useUnorderedNonce(address from, uint256 nonce) private {
        (uint248 wordPos, uint8 bitPos) = bitmapPositions(nonce);
        uint256 bitmap = nonceBitmap[from][wordPos];
        if ((bitmap >> bitPos) & 1 == 1) {
            revert InvalidNonce();
        }
        nonceBitmap[from][wordPos] = bitmap | (1 << bitPos);
    }

    function _validatePermit(address spender, uint256 deadline) private view {
        if (msg.sender != spender) revert NotSpender();
        if (block.timestamp > deadline) revert SignatureExpired();
    }

    function _validateInputLengths(
        uint256 signedTokensLen,
        uint256 recipientLen,
        uint256 signedAmountsLen,
        uint256 requestedAmountsLen
    ) private pure {
        if (signedAmountsLen != signedTokensLen) revert SignedDetailsLengthMismatch();
        if (requestedAmountsLen != signedAmountsLen) revert AmountsLengthMismatch();
        if (recipientLen != 1 && recipientLen != signedTokensLen) revert RecipientLengthMismatch();
    }
}
