// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {
    PermitTransfer,
    Permit,
    Signature,
    SigType,
    DeadlinePassed,
    InvalidSignature,
    LengthMismatch,
    InvalidNonce,
    InsufficentAllowance
} from "./Permit2Utils.sol";
import {Nonces} from "./base/Nonces.sol";
import {DomainSeparator} from "./base/DomainSeparator.sol";
import {AllowanceMath} from "./AllowanceMath.sol";

/// @title AllowanceTransfer
/// @author transmissions11 <t11s@paradigm.xyz>
/// @notice Backwards compatible, low-overhead,
/// next generation token approval/meta-tx system.
abstract contract AllowanceTransfer is DomainSeparator {
    using SafeTransferLib for ERC20;
    using AllowanceMath for uint256;

    bytes32 public constant _PERMIT_TYPEHASH =
        keccak256("Permit(address token,address spender,uint256 allowed,uint256 deadline,bytes32 witness)");

    /*//////////////////////////////////////////////////////////////
                            ALLOWANCE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps users to tokens to spender addresses and information about the approval on the token.
    /// @dev The saved word saves the allowed amount, the timestamp for a given allowed amount, and the nonce.
    mapping(address => mapping(address => mapping(address => uint256))) public allowance;

    /// @notice Approve a spender to transfer a specific
    /// amount of a specific ERC20 token from the sender.
    /// @param token The token to approve.
    /// @param spender The spender address to approve.
    /// @param allowed A uint256 of packed information to store the amount and the timestamp.
    /// @dev The word usually holds a nonce, which will stay unchanged in approve.
    function approve(address token, address spender, uint256 allowed) external {
        // If inputted nonce is less than current nonce, vulnerable to sig replays.
        uint256 current = allowance[msg.sender][token][spender];
        if (allowed.nonce() < current.nonce()) {
            revert InvalidNonce();
        }

        allowance[msg.sender][token][spender] = allowed;
    }

    /*/////////////////////////////////////////////////////f/////////
                              PERMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit a user to spend a given amount of another user's
    /// approved amount of the given token via the owner's EIP-712 signature.
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce.
    function permit(Permit calldata signed, address owner, Signature calldata sig) external returns (address signer) {
        // Ensure the signature's deadline has not already passed.
        if (block.timestamp > signed.deadline) {
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
                            signed.token,
                            signed.spender,
                            signed.allowed,
                            signed.deadline,
                            signed.witness
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

        uint256 current = allowance[signer][signed.token][signed.spender];
        uint256 newNonce = signed.allowed.nonce();

        // New nonce must be strictly greater than current nonce.
        // But, limit how quickly users can invalidate their nonces to
        // ensure no one accidentally invalidates all their nonces.
        if (newNonce <= current.nonce() || newNonce > type(uint16).max) {
            revert InvalidNonce();
        }

        // Set the allowance and timestamp of the spender to the given amount.
        allowance[signer][signed.token][signed.spender] = signed.allowed;
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
        uint256 allowed = allowance[from][token][msg.sender];
        (uint160 allowedAmount, uint64 expiration,) = allowed.unpack();

        if (block.timestamp > expiration) {
            revert DeadlinePassed();
        }

        if (allowedAmount != type(uint160).max) {
            if (allowedAmount < amount) {
                revert InsufficentAllowance();
            } else {
                uint160 newAmount = allowedAmount - amount;
                allowance[from][token][msg.sender] = allowed.setAmount(newAmount);
            }
        }
        // Transfer the tokens from the from address to the recipient.
        ERC20(token).safeTransferFrom(from, to, amount);
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
    function lockdown(address[] calldata tokens, address[] calldata spenders) external {
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
