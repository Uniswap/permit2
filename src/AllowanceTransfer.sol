// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {
    Permit,
    PermitBatch,
    PackedAllowance,
    SignatureExpired,
    AllowanceExpired,
    LengthMismatch,
    InvalidNonce,
    InsufficientAllowance,
    ExcessiveInvalidation
} from "./Permit2Utils.sol";
import {PermitHash} from "./libraries/PermitHash.sol";
import {EIP712} from "./EIP712.sol";

/// TODO comments, headers, interface
/// @title Permit2
/// @author transmissions11 <t11s@paradigm.xyz>
contract AllowanceTransfer is EIP712 {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;
    using PermitHash for Permit;
    using PermitHash for PermitBatch;

    event InvalidateNonces(address indexed owner, uint32 indexed toNonce, address token, address spender);

    /*//////////////////////////////////////////////////////////////
                            ALLOWANCE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps users to tokens to spender addresses and information about the approval on the token.
    /// @dev The saved packed word saves the allowed amount, expiration, and nonce.
    mapping(address => mapping(address => mapping(address => PackedAllowance))) public allowance;

    /// @notice Approves the `spender` to use up to `amount` of the specified `token` up until the `expiration`.
    /// @param token The token to approve.
    /// @param spender The spender address to approve.
    /// @param amount The approved amount of the token.f
    /// @param expiration The duration of the approval.
    /// @dev The packed allowance also holds a nonce, which will stay unchanged in approve.
    function approve(address token, address spender, uint160 amount, uint64 expiration) external {
        PackedAllowance storage allowed = allowance[msg.sender][token][spender];
        allowed.amount = amount;
        allowed.expiration = expiration;
    }

    /*/////////////////////////////////////////////////////f/////////
                              PERMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit a user to spend a given amount of another user's
    /// approved amount of the given token via the owner's EIP-712 signature.
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce.
    /// @param permitData Data signed over by the owner specifying the terms of approval.
    /// @param owner The owner of the tokens being approved.
    /// @param signature The owner's signature over the permit data.
    function permit(Permit calldata permitData, address owner, bytes calldata signature) external {
        PackedAllowance storage allowed = allowance[owner][permitData.token][permitData.spender];
        _validatePermit(allowed.nonce, permitData.nonce, permitData.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitData.hash()), owner);

        unchecked {
            ++allowed.nonce;
        }
        _updateAllowance(allowed, permitData.amount, permitData.expiration);
    }

    function permitBatch(PermitBatch calldata permitData, address owner, bytes calldata signature) external {
        // Use the first token's nonce.
        PackedAllowance storage allowed = allowance[owner][permitData.tokens[0]][permitData.spender];
        _validatePermit(allowed.nonce, permitData.nonce, permitData.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitData.hash()), owner);

        // can do in 1 sstore?
        allowed.amount = permitData.amounts[0];
        allowed.expiration = permitData.expirations[0] == 0 ? uint64(block.timestamp) : permitData.expirations[0];
        ++allowed.nonce;
        unchecked {
            for (uint256 i = 1; i < permitData.tokens.length; ++i) {
                _updateAllowance(
                    allowance[owner][permitData.tokens[i]][permitData.spender],
                    permitData.amounts[i],
                    permitData.expirations[i]
                );
            }
        }
    }

    /// @notice Sets the allowed amount and expiry of the spender's permissions on owner's token.
    /// @dev Nonce has already been incremented.
    function _updateAllowance(PackedAllowance storage allowed, uint160 amount, uint64 expiration) private {
        // If the signed expiration is 0, the allowance only lasts the duration of the block.
        allowed.expiration = expiration == 0 ? uint64(block.timestamp) : expiration;
        allowed.amount = amount;
    }

    function _validatePermit(uint32 nonce, uint32 signedNonce, uint256 sigDeadline) private view {
        // Ensure the signature's deadline has not already passed.
        if (block.timestamp > sigDeadline) revert SignatureExpired();

        // Check current nonce.
        if (nonce != signedNonce) revert InvalidNonce();
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer approved tokens from one address to another.
    /// @param token The token to transfer.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of tokens to transfer.
    /// @dev Requires either the from address to have approved at last the desired amount
    /// of tokens or msg.sender to be approved to manage all of the from addresses's tokens.
    function transferFrom(address token, address from, address to, uint160 amount) external {
        _transfer(token, from, to, amount);
    }

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
    ) external {
        if (amounts.length != to.length || tokens.length != to.length) revert LengthMismatch();

        unchecked {
            for (uint256 i = 0; i < tokens.length; ++i) {
                _transfer(tokens[i], from, to[i], amounts[i]);
            }
        }
    }

    /// @notice Internal function for transferring tokens using stored allowances.
    function _transfer(address token, address from, address to, uint160 amount) private {
        PackedAllowance storage allowed = allowance[from][token][msg.sender];

        if (block.timestamp > allowed.expiration) {
            revert AllowanceExpired();
        }

        uint160 maxAmount = allowed.amount;
        if (maxAmount != type(uint160).max) {
            if (amount > maxAmount) {
                revert InsufficientAllowance();
            } else {
                unchecked {
                    allowed.amount -= amount;
                }
            }
        }
        // Transfer the tokens from the from address to the recipient.
        ERC20(token).safeTransferFrom(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                             LOCKDOWN LOGIC
    //////////////////////////////////////////////////////////////*/

    // TODO: Bench if a struct for token-spender pairs is cheaper.
    // TODO test
    /// @notice Enables performing a "lockdown" of the sender's Permit2 identity
    /// by batch revoking approvals, and invalidating ordered nonces.
    /// @param tokens An array of tokens who's corresponding spenders should have their
    /// approvals revoked. Each index should correspond to an index in the spenders array.
    /// @param spenders An array of addresses to revoke approvals from.
    /// Each index should correspond to an index in the tokens array.
    function lockdown(address[] calldata tokens, address[] calldata spenders) external {
        // Each index should correspond to an index in the other array.
        if (tokens.length != spenders.length) revert LengthMismatch();

        // Revoke allowances for each pair of spenders and tokens.
        unchecked {
            for (uint256 i = 0; i < spenders.length; ++i) {
                allowance[msg.sender][tokens[i]][spenders[i]].amount = 0;
            }
        }
    }

    /// @notice invalidate nonces for a given (token, spender) pair
    /// @dev token The token to invalidate nonces for
    /// @dev spender The spender to invalidate nonces for
    /// @dev amountToInvalidate The number of nonces to invalidate. Capped at 2**16.
    function invalidateNonces(address token, address spender, uint32 amountToInvalidate)
        public
        returns (uint32 newNonce)
    {
        if (amountToInvalidate > type(uint16).max) revert ExcessiveInvalidation();

        unchecked {
            // Overflow is impossible on human timescales.
            newNonce = allowance[msg.sender][token][spender].nonce += amountToInvalidate;
        }

        emit InvalidateNonces(msg.sender, newNonce, token, spender);
    }
}
