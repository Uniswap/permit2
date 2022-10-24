// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title AllowanceTransfer
/// @notice Handles ERC20 token transfers through signature based actions
/// @dev Requires user's token approval on the Permit2 contract
interface IAllowanceTransfer {
    error AllowanceExpired();
    error InsufficientAllowance();
    error ExcessiveInvalidation();

    /// @notice Emits an event when the owner successfully invalidates an ordered nonce.
    event InvalidateNonces(address indexed owner, uint32 indexed toNonce, address token, address spender);

    /// @notice Emits an event when the owner successfully sets permissions on a token for the spender.
    event Approval(
        address indexed owner, address indexed token, address indexed spender, uint160 amount, uint64 expiration
    );

    /// @notice Emits an event when the owner successfully sets permissions on a set of tokens for the spender.
    event BatchedApproval(
        address indexed owner, address[] tokens, address indexed spender, uint160[] amount, uint64[] expiration
    );

    /// @notice Emits an event when the token is successfully transferred.
    event Transfer(address indexed from, address indexed token, address indexed to, uint160 amount);

    /// @notice Emits an event when a set of tokens are successfully transferred.
    event BatchedTransfer(address indexed from, address[] tokens, address[] to, uint160[] amounts);

    /// @notice The signed permit message for a single token allowance
    struct Permit {
        // ERC20 token address
        address token;
        // address permissioned on the allowed tokens
        address spender;
        // the maximum amount allowed to spend
        uint160 amount;
        // timestamp at which a spender's token allowances become invalid
        uint64 expiration;
        // a unique value for each signature
        uint32 nonce;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    /// @notice The signed permit message for multiple token allowances
    struct PermitBatch {
        // ERC20 token addresses
        address[] tokens;
        // address permissioned on the allowed tokens
        address spender;
        // the maximum amounts allowed to spend per token
        uint160[] amounts;
        // timestamp at which a spender's token allowances become invalid, assigned per token
        uint64[] expirations;
        // a unique value for each signature
        uint32 nonce;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    /// @notice The saved permissions
    /// @dev This info is saved per owner, per token, per spender and all signed over in the permit message
    struct PackedAllowance {
        // amount allowed
        uint160 amount;
        // permission expiry
        uint64 expiration;
        // a unique value for each signature
        uint32 nonce;
    }

    /// @notice Approves the spender to use up to amount of the specified token up until the expiration
    /// @param token The token to approve
    /// @param spender The spender address to approve
    /// @param amount The approved amount of the token
    /// @param expiration The timestamp at which the approval is no longer valid
    /// @dev The packed allowance also holds a nonce, which will stay unchanged in approve
    function approve(address token, address spender, uint160 amount, uint64 expiration) external;

    /// @notice Permit a spender to a given amount of the owners token via the owner's EIP-712 signature
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param permitData Data signed over by the owner specifying the terms of approval
    /// @param owner The owner of the tokens being approved
    /// @param signature The owner's signature over the permit data
    function permit(Permit calldata permitData, address owner, bytes calldata signature) external;

    /// @notice Permit a spender to the signed amounts of the owners tokens via the owner's EIP-712 signature
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param permitData Data signed over by the owner specifying the terms of approval
    /// @param owner The owner of the tokens being approved
    /// @param signature The owner's signature over the permit data
    function permitBatch(PermitBatch calldata permitData, address owner, bytes calldata signature) external;

    /// @notice Transfer approved tokens from one address to another.
    /// @param token The token to transfer.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of tokens to transfer.
    /// @dev Requires either the from address to have approved at least the desired amount
    /// of tokens or msg.sender to be approved to manage all of the from addresses's tokens.
    function transferFrom(address token, address from, address to, uint160 amount) external;

    /// @notice Transfer approved tokens in a batch
    /// @param tokens Array of token addresses to transfer
    /// @param from The address to transfer tokens from
    /// @param to Array of recipients for the transfers
    /// @param amounts Array of token amounts to transfer
    function batchTransferFrom(
        address[] calldata tokens,
        address from,
        address[] calldata to,
        uint160[] calldata amounts
    ) external;

    /// @notice Enables performing a "lockdown" of the sender's Permit2 identity
    /// by batch revoking approvals
    /// @param tokens An array of tokens who's corresponding spenders should have their
    /// approvals revoked. Each index should correspond to an index in the spenders array
    /// @param spenders An array of addresses to revoke approvals from
    /// Each index should correspond to an index in the tokens array
    function lockdown(address[] calldata tokens, address[] calldata spenders) external;

    /// @notice Invalidate nonces for a given (token, spender) pair
    /// @dev token The token to invalidate nonces for
    /// @dev spender The spender to invalidate nonces for
    /// @dev amountToInvalidate The number of nonces to invalidate. Capped at 2**16
    function invalidateNonces(address token, address spender, uint32 amountToInvalidate)
        external
        returns (uint32 newNonce);
}
