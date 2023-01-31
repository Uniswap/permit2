// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title AllowanceTransfer
/// @notice Handles ERC721 token permissions through signature based allowance setting and ERC721 token transfers by checking stored permissions
/// @dev Requires user's token approval on the Permit2 contract
interface IAllowanceTransferERC721 {
    /// @notice Thrown when an allowance on a token has expired.
    /// @param allowanceDeadline The timestamp at which the permissions on the token for a specific tokenId are no longer valid
    /// @param operatorDeadline The timestamp at which the permissions given to an operator of an entire collection are no longer valid.
    error AllowanceExpired(uint256 allowanceDeadline, uint256 operatorDeadline);

    /// @notice Thrown when there is no allowance for a token.
    /// @param token The address of the token and tokenId
    error InsufficientAllowance(address token, uint256 tokenId);

    /// @notice Thrown when too many nonces are invalidated.
    error ExcessiveInvalidation();

    /// @notice Emits an event when the owner successfully invalidates an ordered nonce on the operator mapping.
    event NonceInvalidation(
        address indexed owner, address indexed token, address indexed spender, uint48 newNonce, uint48 oldNonce
    );

    /// @notice Emits an event when the owner successfully invalidates an ordered nonce on the allowance mapping.
    event NonceInvalidation(
        address indexed owner, address indexed token, uint256 indexed tokenId, uint48 newNonce, uint48 oldNonce
    );

    /// @notice Emits an event when the owner successfully sets permissions on a token for the spender.
    event Approval(
        address indexed owner, address indexed token, address indexed spender, uint256 tokenId, uint48 expiration
    );

    /// @notice Emits an event when the owner successfully gives a spender operator permissions on a token.
    event ApprovalForAll(address indexed owner, address indexed token, address indexed spender, uint48 expiration);

    /// @notice Emits an event when the owner successfully sets permissions using a permit signature on a token for the spender.
    event Permit(
        address indexed owner,
        address indexed token,
        address indexed spender,
        uint256 tokenId,
        uint48 expiration,
        uint48 nonce
    );

    /// @notice Emits an event when the owner sets the allowance back to 0 with the lockdown function.
    event Lockdown(address indexed owner, address token, address spender);

    /// @notice The permit data for a token
    struct PermitDetails {
        // ERC20 token address
        address token;
        // the tokenId allowed to spend
        uint256 tokenId;
        // timestamp at which a spender's token allowances become invalid
        uint48 expiration;
        // an incrementing value indexed per owner,token,and tokenId for each signature
        uint48 nonce;
    }

    /// @notice The permit message signed for a single token allownce
    struct PermitSingle {
        // the permit data for a single token alownce
        PermitDetails details;
        // address permissioned on the allowed tokens
        address spender;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    /// @notice The permit message signed for multiple token allowances
    struct PermitBatch {
        // the permit data for multiple token allowances
        PermitDetails[] details;
        // address permissioned on the allowed tokens
        address spender;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    /// @notice The permit message signed to set an operator for the token.
    struct PermitAll {
        // address of the token collection
        address token;
        // address of the spender who will act as an operator on all tokenIds owned by the signer for the token collection
        address spender;
        // expiration of the operator permissions
        uint48 expiration;
        // an incrementing value indexed per owner, per token, per spender
        uint48 nonce;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

    /// @notice The saved permissions on the allowance mapping
    /// @dev This info is saved per owner, per token, per tokenId and all signed over in the permit message
    struct PackedAllowance {
        // spender allowed
        address spender;
        // permission expiry
        uint48 expiration;
        // an incrementing value indexed per owner,token,and spender for each signature
        uint48 nonce;
    }

    /// @notice The saved expiration on the operator.
    /// @dev Holds a nonce value to provide replay protection.
    struct PackedOperatorAllowance {
        uint48 expiration;
        uint48 nonce;
    }

    /// @notice A token spender pair.
    struct TokenSpenderPair {
        // the token the spender is approved
        address token;
        // the spender address
        address spender;
    }

    /// @notice A token and tokenId pair.
    struct TokenAndIdPair {
        // the token collection address
        address token;
        // the tokenId
        uint256 tokenId;
    }

    /// @notice Details for a token transfer.
    struct AllowanceTransferDetails {
        // the owner of the token
        address from;
        // the recipient of the token
        address to;
        // the tokenId of the token
        uint256 tokenId;
        // the token to be transferred
        address token;
    }

    /// @notice A mapping from owner address to token address to tokenId to PackedAllowance struct, which contains details and conditions of the approval.
    /// @notice The mapping is indexed in the above order see: allowance[ownerAddress][tokenAddress][tokenId]
    /// @dev The packed slot holds the allowed spender, expiration at which the permissions on the tokenId is no longer valid, and current nonce thats updated on any signature based approvals.
    /// @dev Setting the expiration to 0, sets the expiration to block.timestamp so the approval only lasts for the duration of the block.
    function allowance(address, address, uint256) external view returns (address, uint48, uint48);

    /// @notice A mapping from owner address to token address to spender address to a PackedOperatorAllowance struct, which contains the expiration of the operator approval.
    /// @notice The mapping is indexed in the above order see: operator[ownerAddress][tokenAddress][spenderAddress]
    /// @dev Unlike the allowance mappings, setting the expiration to 0 just invalidates the operator allowance. It does NOT set the allowance to block.timestamp.
    function operators(address, address, address) external view returns (uint48, uint48);

    /// @notice Approves the spender to transfer the tokenId of the specified token up until the expiration
    /// @param token The token to approve
    /// @param spender The spender address to approve
    /// @param tokenId The approved tokenId of the token
    /// @param expiration The timestamp at which the approval is no longer valid
    /// @dev The packed allowance also holds a nonce, which will stay unchanged in approve
    /// @dev Passing in expiration as 0 sets the expiration to the block.timestamp
    function approve(address token, address spender, uint256 tokenId, uint48 expiration) external;

    /// @notice Approves the spender to be an operator of the specified token up until the expiration
    /// @param token The token to approve
    /// @param spender The spender address to approve
    /// @param expiration The timestamp at which the operator approval is no longer valid
    /// @dev The packed allowance also holds a nonce, which will stay unchanged in approve
    /// @dev Passing in expiration as 0 DOES NOT set the expiration to the block.timestamp unlike `approve`.
    function setApprovalForAll(address token, address spender, uint48 expiration) external;

    /// @notice Permit a spender to a given tokenId of the owners token via the owner's EIP-712 signature
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param owner The owner of the tokens being approved
    /// @param permitSingle Data signed over by the owner specifying the terms of approval
    /// @param signature The owner's signature over the permit data
    function permit(address owner, PermitSingle memory permitSingle, bytes calldata signature) external;

    /// @notice Permit a spender to the signed tokenIds of the owners tokens via the owner's EIP-712 signature
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param owner The owner of the tokens being approved
    /// @param permitBatch Data signed over by the owner specifying the terms of approval
    /// @param signature The owner's signature over the permit data
    function permit(address owner, PermitBatch memory permitBatch, bytes calldata signature) external;

    /// @notice Permit a spender to be an operator of the owners tokens via the owner's EIP-712 signature
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce
    /// @param owner The owner of the tokens being approved
    /// @param permitAll Data signed over by the owner specifying the terms of approval
    /// @param signature The owner's signature over the permit data
    function permit(address owner, PermitAll memory permitAll, bytes calldata signature) external;

    /// @notice Transfer approved tokens from one address to another
    /// @param from The address to transfer from
    /// @param to The address of the recipient
    /// @param tokenId The tokenId of the token to transfer
    /// @param token The token address to transfer
    /// @dev Requires the from address to have approved the desired tokenId or be an operator
    /// of the token to msg.sender.
    function transferFrom(address from, address to, uint256 tokenId, address token) external;

    /// @notice Transfer approved tokens in a batch
    /// @param transferDetails Array of owners, recipients, tokenIds, and tokens for the transfers
    /// @dev Requires the from addresses to have approved the desired tokenIds or be an operator
    /// of the tokens to msg.sender.
    function transferFrom(AllowanceTransferDetails[] calldata transferDetails) external;

    /// @notice Enables performing a "lockdown" of the sender's Permit2 identity
    /// by batch revoking approvals
    /// @param operatorApprovals Array of operator approvals to revoke.
    /// @param tokenIdApprovals Array of tokenId approvals to revoke.
    /// @dev Expires the allowances on each of the approval mappings, the operator and allowance mappings respectively.
    function lockdown(TokenSpenderPair[] calldata operatorApprovals, TokenAndIdPair[] calldata tokenIdApprovals)
        external;

    /// @notice Invalidate nonces for a given (token, spender) pair
    /// @param token The token to invalidate nonces for
    /// @param spender The spender to invalidate nonces for
    /// @param newNonce The new nonce to set. Invalidates all nonces less than it.
    /// @dev Can't invalidate more than 2**16 nonces per transaction.
    function invalidateNonces(address token, address spender, uint48 newNonce) external;

    /// @notice Invalidate nonces for a given (token, tokenId) pair
    /// @param token The token to invalidate nonces for
    /// @param tokenId The tokenId to invalidate nonces for
    /// @param newNonce The new nonce to set. Invalidates all nonces less than it.
    /// @dev Can't invalidate more than 2**16 nonces per transaction.
    function invalidateNonces(address token, uint256 tokenId, uint48 newNonce) external;
}
