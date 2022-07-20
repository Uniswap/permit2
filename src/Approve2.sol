// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// todo: multicall or at least batch revoke approval thing (lock down all approvals)

/// @title Approve2
/// @author transmissions11 <t11s@paradigm.xyz>
/// @notice Backwards compatible, low-overhead,
/// next generation token approval/meta-tx system.
contract Approve2 {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                          EIP-712 STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps addresses to their current nonces. Used to prevent replay
    /// attacks and allow invalidating in-flight permits via invalidateNonce.
    mapping(address => uint256) public nonces;

    /// @notice Invalidate a specific number of nonces. Can be used
    /// to invalidate in-flight permits before they are executed.
    /// @param noncesToInvalidate The number of nonces to invalidate.
    function invalidateNonce(uint256 noncesToInvalidate) external {
        nonces[msg.sender] += noncesToInvalidate;
    }

    /// @notice The EIP-712 "domain separator" the contract
    /// will use when validating signatures for a given token.
    /// @param token The token to get the domain separator for.
    /// @dev For calls to permitAll, the address of
    /// the Approve2 contract will be used the token.
    function DOMAIN_SEPARATOR(address token) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("Approve2"),
                    keccak256("1"),
                    block.chainid,
                    token // We use the token's address for easy frontend compatibility.
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOWANCE STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps user addresses to spender addresses and whether they are
    /// are approved to spend any amount of any token the user has approved.
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// @notice Maps users to tokens to spender addresses and how much they
    /// are approved to spend the amount of that token the user has approved.
    mapping(address => mapping(ERC20 => mapping(address => uint256))) public allowance;

    /// @notice Set whether an spender address is approved
    /// to transfer any one of the sender's approved tokens.
    /// @param spender The spender address to approve or unapprove.
    /// @param approved Whether the spender is approved.
    function approveForAll(address spender, bool approved) public {
        isApprovedForAll[msg.sender][spender] = approved;
    }

    /// @notice Approve a spender to transfer a specific
    /// amount of a specific ERC20 token from the sender.
    /// @param token The token to approve.
    /// @param spender The spender address to approve.
    /// @param amount The amount of the token to approve.
    function approve(
        ERC20 token,
        address spender,
        uint256 amount
    ) public {
        allowance[msg.sender][token][spender] = amount;
    }

    /*//////////////////////////////////////////////////////////////
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
                        DOMAIN_SEPARATOR(address(token)),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                amount,
                                nonces[owner]++,
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

    /// @notice Permit a user to spend any amount of any of another
    /// user's approved tokens via the owner's EIP-712 signature.
    /// @param owner The user to permit spending from.
    /// @param spender The user to permit spending to.
    /// @param deadline The timestamp after which the signature is no longer valid.
    /// @param v Must produce valid secp256k1 signature from the owner along with r and s.
    /// @param r Must produce valid secp256k1 signature from the owner along with v and s.
    /// @param s Must produce valid secp256k1 signature from the owner along with r and v.
    /// @dev May fail if the owner's nonce was invalidated in-flight by invalidateNonce.
    function permitAll(
        address owner,
        address spender,
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
                        DOMAIN_SEPARATOR(address(this)),
                        keccak256(
                            abi.encode(
                                keccak256("PermitAll(address owner,address spender,uint256 nonce,uint256 deadline)"),
                                owner,
                                spender,
                                nonces[owner]++,
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

            // Set isApprovedForAll for the spender to true.
            isApprovedForAll[owner][spender] = true;
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
    function transferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) external {
        unchecked {
            uint256 allowed = allowance[from][token][msg.sender]; // Saves gas for limited approvals.

            // If the from address has set an unlimited approval, we'll go straight to the transfer.
            if (allowed != type(uint256).max) {
                if (allowed >= amount) {
                    // If msg.sender has enough approved to them, decrement their allowance.
                    allowance[from][token][msg.sender] = allowed - amount;
                } else {
                    // Otherwise, check if msg.sender has an approval for all of the from
                    // address's tokens, otherwise we'll revert and block the transfer.
                    require(isApprovedForAll[from][msg.sender], "APPROVE_ALL_REQUIRED");
                }
            }

            // Transfer the tokens from the from address to the recipient.
            token.safeTransferFrom(from, to, amount);
        }
    }
}
