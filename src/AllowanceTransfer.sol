// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @title AllowanceTransfer
/// @author transmissions11 <t11s@paradigm.xyz>
/// @notice Backwards compatible, low-overhead,
/// next generation token approval/meta-tx system.
abstract contract AllowanceTransfer {
    using SafeTransferLib for ERC20;

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32);
    function _useNonce(address from, uint256 nonce) internal virtual;
    function increaseNonce(address owner) internal virtual returns (uint256 nonce);
    function invalidateNonces(uint256 amount) public virtual;

    /*//////////////////////////////////////////////////////////////
                            ALLOWANCE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps users to tokens to spender addresses and how much they
    /// are approved to spend the amount of that token the user has approved.
    mapping(address => mapping(ERC20 => mapping(address => uint256))) public allowance;

    /// @notice Approve a spender to transfer a specific
    /// amount of a specific ERC20 token from the sender.
    /// @param token The token to approve.
    /// @param spender The spender address to approve.
    /// @param amount The amount of the token to approve.
    function approve(ERC20 token, address spender, uint256 amount) external {
        allowance[msg.sender][token][spender] = amount;
    }

    /*/////////////////////////////////////////////////////f/////////
                              PERMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit a user to spend a given amount of another user's
    /// approved amount of the given token via the owner's EIP-712 signature.
    /// @param token The token to permit spending.
    /// @param owner The user to permit spending from.
    /// @param spender The user to permit spending to.
    /// @param amount The amount to permit spending.
    /// @param deadline  The timestamp after which the signature is no longer valid.
    /// @param v Must produce valid secp256k1 signature from the owner along with r and s.
    /// @param r Must produce valid secp256k1 signature from the owner along with v and s.
    /// @param s Must produce valid secp256k1 signature from the owner along with r and v.
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce.
    function permit(
        ERC20 token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        unchecked {
            // Ensure the signature's deadline has not already passed.
            require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

            // Recover the signer address from the signature.
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                amount,
                                increaseNonce(owner),
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            // Ensure the signature is valid and the signer is the owner.
            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            // Set the allowance of the spender to the given amount.
            allowance[recoveredAddress][token][spender] = amount;
        }
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
    function transferFrom(ERC20 token, address from, address to, uint256 amount) external {
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
            token.safeTransferFrom(from, to, amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             LOCKDOWN LOGIC
    //////////////////////////////////////////////////////////////*/

    // TODO: Bench if a struct for token-spender pairs is cheaper.

    /// @notice Enables performing a "lockdown" of the sender's Permit2 identity
    /// by batch revoking approvals, and invalidating nonces.
    /// @param tokens An array of tokens who's corresponding spenders should have their
    /// approvals revoked. Each index should correspond to an index in the spenders array.
    /// @param spenders An array of addresses to revoke approvals from.
    /// Each index should correspond to an index in the tokens array.
    function lockdown(ERC20[] calldata tokens, address[] calldata spenders, uint256 noncesToInvalidate) external {
        unchecked {
            // Will revert if trying to invalidate
            // more than type(uint16).max nonces.
            invalidateNonces(noncesToInvalidate);

            // Each index should correspond to an index in the other array.
            require(tokens.length == spenders.length, "LENGTH_MISMATCH");

            // Revoke allowances for each pair of spenders and tokens.
            for (uint256 i = 0; i < spenders.length; ++i) {
                delete allowance[msg.sender][tokens[i]][spenders[i]];
            }
        }
    }
}
