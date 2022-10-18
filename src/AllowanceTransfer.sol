// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Permit, Signature, SigType, DeadlinePassed, InvalidSignature, LengthMismatch} from "./Permit2Utils.sol";

/// @title AllowanceTransfer
/// @author transmissions11 <t11s@paradigm.xyz>
/// @notice Backwards compatible, low-overhead,
/// next generation token approval/meta-tx system.
abstract contract AllowanceTransfer {
    using SafeTransferLib for ERC20;

    bytes32 public constant _PERMIT_TYPEHASH = keccak256(
        "Permit(uint8 sigType,address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32);
    function _useNonce(address from, uint256 nonce) internal virtual;
    function _useUnorderedNonce(address from, uint256 nonce) internal virtual;
    function invalidateNonces(uint256 amount) public virtual;
    function invalidateUnorderedNonces(uint248 wordPos, uint256 mask) public virtual;

    /*//////////////////////////////////////////////////////////////
                            ALLOWANCE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps users to tokens to spender addresses and how much they
    /// are approved to spend the amount of that token the user has approved.
    mapping(address => mapping(address => mapping(address => uint256))) public allowance;

    /// @notice Approve a spender to transfer a specific
    /// amount of a specific ERC20 token from the sender.
    /// @param token The token to approve.
    /// @param spender The spender address to approve.
    /// @param amount The amount of the token to approve.
    function approve(address token, address spender, uint256 amount) external {
        allowance[msg.sender][token][spender] = amount;
    }

    /*/////////////////////////////////////////////////////f/////////
                              PERMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit a user to spend a given amount of another user's
    /// approved amount of the given token via the owner's EIP-712 signature.
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce.
    function permit(Permit calldata permitData, address owner, Signature calldata sig)
        external
        returns (address signer)
    {
        // Ensure the signature's deadline has not already passed.
        if (block.timestamp > permitData.deadline) {
            revert DeadlinePassed();
        }

        // Recover the signer address from the signature.
        signer = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            _PERMIT_TYPEHASH,
                            permitData.sigType,
                            permitData.token,
                            permitData.spender,
                            permitData.maxAmount,
                            permitData.nonce,
                            permitData.deadline,
                            permitData.witness
                        )
                    )
                )
            ),
            sig.v,
            sig.r,
            sig.s
        );

        if (signer == address(0) || signer != owner) {
            revert InvalidSignature();
        }

        if (permitData.sigType == SigType.ORDERED) {
            _useNonce(signer, permitData.nonce);
        } else if (permitData.sigType == SigType.UNORDERED) {
            _useUnorderedNonce(signer, permitData.nonce);
        }

        // Set the allowance of the spender to the given amount.
        allowance[signer][permitData.token][permitData.spender] = permitData.maxAmount;
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
    function transferFrom(address token, address from, address to, uint256 amount) external {
        unchecked {
            uint256 allowed = allowance[from][token][msg.sender]; // Saves gas for limited approvals.

            // If the from address has set an unlimited approval, we'll go straight to the transfer.
            if (allowed != type(uint256).max) {
                if (allowed >= amount) {
                    // If msg.sender has enough approved to them, decrement their allowance.
                    allowance[from][token][msg.sender] = allowed - amount;
                }
            }

            // Transfer the tokens from the from address to the recipient.
            ERC20(token).safeTransferFrom(from, to, amount);
        }
    }

    // TODO transferFromBatch

    /*//////////////////////////////////////////////////////////////
                             LOCKDOWN LOGIC
    //////////////////////////////////////////////////////////////*/

    // TODO: Bench if a struct for token-spender pairs is cheaper.

    /// @notice Enables performing a "lockdown" of the sender's Permit2 identity
    /// by batch revoking approvals, and invalidating ordered nonces.
    /// @param tokens An array of tokens who's corresponding spenders should have their
    /// approvals revoked. Each index should correspond to an index in the spenders array.
    /// @param spenders An array of addresses to revoke approvals from.
    /// Each index should correspond to an index in the tokens array.
    /// @param noncesToInvalidate The amount to increase the nonce mapping with.
    /// @dev Overloaded function. This invalidates unordered nonces.
    function lockdown(address[] calldata tokens, address[] calldata spenders, uint256 noncesToInvalidate) external {
        invalidateNonces(noncesToInvalidate);

        // Each index should correspond to an index in the other array.
        if (tokens.length != spenders.length) {
            revert LengthMismatch();
        }

        // Revoke allowances for each pair of spenders and tokens.
        unchecked {
            for (uint256 i = 0; i < spenders.length; ++i) {
                delete allowance[msg.sender][tokens[i]][spenders[i]];
            }
        }
    }

    /// @notice Enables performing a "lockdown" of the sender's Permit2 identity
    /// by batch revoking approvals, and invalidating the unordered nonces.
    /// @param tokens An array of tokens who's corresponding spenders should have their
    /// approvals revoked. Each index should correspond to an index in the spenders array.
    /// @param spenders An array of addresses to revoke approvals from.
    /// Each index should correspond to an index in the tokens array.
    /// @param wordPos The word position of the nonceBitmap to index.
    /// @param mask The mask used to flip bits in the bitmap, erasing any orders that use those bits as the nonce randomness.
    /// @dev Overloaded function. This invalidates unordered nonces.
    function lockdown(address[] calldata tokens, address[] calldata spenders, uint248 wordPos, uint256 mask) external {
        invalidateUnorderedNonces(wordPos, mask);

        // Each index should correspond to an index in the other array.
        if (tokens.length != spenders.length) {
            revert LengthMismatch();
        }

        // Revoke allowances for each pair of spenders and tokens.
        unchecked {
            for (uint256 i = 0; i < spenders.length; ++i) {
                delete allowance[msg.sender][tokens[i]][spenders[i]];
            }
        }
    }
}
