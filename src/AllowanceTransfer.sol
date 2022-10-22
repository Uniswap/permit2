// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {
    Permit,
    PackedAllowance,
    SignatureExpired,
    AllowanceExpired,
    LengthMismatch,
    InvalidNonce,
    InsufficientAllowance,
    ExcessiveInvalidation
} from "./Permit2Utils.sol";
import {DomainSeparator} from "./DomainSeparator.sol";

/// TODO comments, headers, interface
/// @title Permit2
/// @author transmissions11 <t11s@paradigm.xyz>
contract AllowanceTransfer is DomainSeparator {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;

    bytes32 public constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address token,address spender,uint160 amount,uint64 expiration,uint32 nonce,uint256 sigDeadline)"
    );

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
    /// @param amount The approved amount of the token.
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
    function permit(Permit calldata permitData, address owner, bytes calldata signature) external {
        // Ensure the signature's deadline has not already passed.
        if (block.timestamp > permitData.sigDeadline) {
            revert SignatureExpired();
        }

        // Check current nonce (incremented below).
        if (permitData.nonce != allowance[owner][permitData.token][permitData.spender].nonce) {
            revert InvalidNonce();
        }

        // Verify the signer address from the signature.
        signature.verify(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            _PERMIT_TYPEHASH,
                            permitData.token,
                            permitData.spender,
                            permitData.amount,
                            permitData.expiration,
                            permitData.nonce,
                            permitData.sigDeadline
                        )
                    )
                )
            ),
            owner
        );

        // If the signed expiration expiration is 0, the allowance only lasts the duration of the block.
        uint64 expiration = permitData.expiration == 0 ? uint64(block.timestamp) : permitData.expiration;

        // Set the allowance, timestamp, and incremented nonce of the spender's permissions on signer's token.
        allowance[owner][permitData.token][permitData.spender] =
            PackedAllowance({amount: permitData.amount, expiration: expiration, nonce: permitData.nonce + 1});
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer approved tokens from one address to another.
    /// @param token The token to transfer.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of tokens to transfer.
    /// @dev Requires either the from address to have approved at least the desired amount
    /// of tokens or msg.sender to be approved to manage all of the from addresses's tokens.
    function transferFrom(address token, address from, address to, uint160 amount) external {
        _transfer(token, from, to, amount);
    }

    function batchTransferFrom(address[] calldata token, address from, address[] calldata to, uint160[] calldata amount)
        external
    {
        if (amount.length != to.length || token.length != to.length) {
            revert LengthMismatch();
        }
        unchecked {
            for (uint256 i = 0; i < token.length; ++i) {
                _transfer(token[i], from, to[i], amount[i]);
            }
        }
    }

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
        if (tokens.length != spenders.length) {
            revert LengthMismatch();
        }

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
    function invalidateNonces(address token, address spender, uint32 amountToInvalidate) public {
        if (amountToInvalidate > type(uint16).max) revert ExcessiveInvalidation();

        uint32 newNonce = allowance[msg.sender][token][spender].nonce + amountToInvalidate;
        allowance[msg.sender][token][spender].nonce = newNonce;
        emit InvalidateNonces(msg.sender, newNonce, token, spender);
    }
}
