// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title SignatureTransfer
/// @notice Handles ERC20 token transfers through signature based actions
/// @dev Requires user's token approval on the Permit2 contract
interface ISignatureTransfer {
    error NotSpender();
    error InvalidAmount();
    error SignedDetailsLengthMismatch();
    error AmountsLengthMismatch();

    /// @notice Emits an event when the owner successfully invalidates an unordered nonce.
    event InvalidateUnorderedNonces(address indexed owner, uint256 word, uint256 mask);

    /// @notice Used to reconstruct the signed permit message for a single token transfer
    /// @dev Do not need to pass in spender address as it is required that it is msg.sender
    /// @dev Note that a user still signs over a spender address
    struct PermitTransferFrom {
        // ERC20 token address
        address token;
        // the maximum amount that can be spent
        uint256 signedAmount;
        // a unique value for each signature
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    /// @notice A pair holding recipient address and amount for transfers.
    struct ToAmountPair {
        address to;
        uint256 requestedAmount;
    }

    /// @notice Used to reconstruct the signed permit message for multiple token transfers
    /// @dev Do not need to pass in spender address as it is required that it is msg.sender
    /// @dev Note that a user still signs over a spender address
    struct PermitBatchTransferFrom {
        // ERC20 token addresses
        address[] tokens;
        // the maximum amounts that can be spent per token
        uint256[] signedAmounts;
        // a unique value for each signature
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    /// @notice A bitmap used for replay protection
    /// @dev Uses unordered nonces so that permit messages do not need to be spent in a certain order
    function nonceBitmap(address, uint256) external returns (uint256);

    /// @notice Transfers a token using a signed permit message
    /// @dev If to is the zero address, the tokens are sent to the signed spender
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param to The recipient of the tokens
    /// @param requestedAmount The amount of tokens to transfer
    /// @param signature The signature to verify
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        address owner,
        address to,
        uint256 requestedAmount,
        bytes calldata signature
    ) external;

    /// @notice Transfers a token using a signed permit message
    /// @notice Includes extra data provided by the caller to verify signature over
    /// @dev If to is the zero address, the tokens are sent to the spender
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param to The recipient of the tokens
    /// @param requestedAmount The amount of tokens to transfer
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeName The name of the witness type
    /// @param witnessType The EIP-712 type definition for the witness type
    /// @param signature The signature to verify
    function permitWitnessTransferFrom(
        PermitTransferFrom calldata permit,
        address owner,
        address to,
        uint256 requestedAmount,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType,
        bytes calldata signature
    ) external;

    /// @notice Transfers multiple tokens using a signed permit message
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param signature The signature to verify
    function permitBatchTransferFrom(
        PermitBatchTransferFrom calldata permit,
        address owner,
        ToAmountPair[] calldata ToAmountPairs,
        bytes calldata signature
    ) external;

    /// @notice Transfers multiple tokens using a signed permit message
    /// @notice Includes extra data provided by the caller to verify signature over
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeName The name of the witness type
    /// @param witnessType The EIP-712 type definition for the witness type
    /// @param signature The signature to verify
    function permitBatchWitnessTransferFrom(
        PermitBatchTransferFrom calldata permit,
        address owner,
        ToAmountPair[] calldata ToAmountPairs,
        bytes32 witness,
        string calldata witnessTypeName,
        string calldata witnessType,
        bytes calldata signature
    ) external;

    /// @notice Invalidates the bits specified in mask for the bitmap at the word position
    /// @dev The wordPos is maxed at type(uint248).max
    /// @param wordPos A number to index the nonceBitmap at
    /// @param mask A bitmap masked against msg.sender's current bitmap at the word position
    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external;
}
