// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Approve2} from "./Approve2.sol";

// TODO: DAI special case

/// @title Approve2Lib
/// @author transmissions11 <t11s@paradigm.xyz>
/// @notice Library that enables efficient transfers
/// meta-txs for any token by falling back to Approve2.
library Approve2Lib {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    Approve2 constant approve2 = Approve2(address(0xBEEF));

    /*//////////////////////////////////////////////////////////////
                              PERMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit a user to spend a given amount of
    /// another user's tokens via the owner's EIP-712 signature.
    /// @param token The token to permit spending.
    /// @param owner The user to permit spending from.
    /// @param spender The user to permit spending to.
    /// @param amount The amount to permit spending.
    /// @param deadline  The timestamp after which the signature is no longer valid.
    /// @param v Must produce valid secp256k1 signature from the owner along with r and s.
    /// @param r Must produce valid secp256k1 signature from the owner along with v and s.
    /// @param s Must produce valid secp256k1 signature from the owner along with r and v.
    function permit2(
        ERC20 token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // TODO: safePermit? it could fail silently like with WETH right? fuck. add to solmate?

        // TODO: idt the returndata decoding for nonce will be caught, should test with weth

        // Get and cache the starting nonce.
        try token.nonces(owner) returns (uint256 nonce) {
            // Attempt to call permit on the token.
            try token.permit(owner, spender, amount, deadline, v, r, s) {} catch {
                // If permit didn't work, then we need to check if the owner is the spender.
                if (token.nonces(owner) != nonce + 1) approve2.permit(owner, spender, amount, deadline, v, r, s);
            }
        } catch {
            // If there is no nonce function, go straight to Approve2.
            approve2.permit(owner, spender, amount, deadline, v, r, s);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer a given amount of tokens from one user to another.
    /// @param token The token to transfer.
    /// @param from The user to transfer from.
    /// @param to The user to transfer to.
    /// @param amount The amount to transfer.
    function transferFrom2(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        // Attempt to safeTransferFrom, exiting immediately if it succeeds.
        if (safeTransferFrom(token, from, to, amount)) return;

        // Otherwise fallback to trying the transfer via Approve2.
        approve2TransferFrom(token, from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           SAFE TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Safely transfer a given amount of tokens from one user to another.
    /// @param token The token to transfer.
    /// @param from The user to transfer from.
    /// @param to The user to transfer to.
    /// @param amount The amount to transfer.
    /// @return success True if the transfer was successful, false otherwise.
    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal returns (bool success) {
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }
    }

    /// @dev Transfer a given amount of tokens from one user to another using Approve2.
    /// @param token The token to transfer.
    /// @param from The user to transfer from.
    /// @param to The user to transfer to.
    /// @param amount The amount to transfer.
    /// @return success True if the transfer was successful, false otherwise.
    function approve2TransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal returns (bool success) {
        // Can't access address constants directly
        // in inline assembly, so we must do this.
        address approve2Address = address(approve2);

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x15dacbea00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), token) // Append the "token" argument.
            mstore(add(freeMemoryPointer, 36), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 68), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 100), amount) // Append the "amount" argument.

            // Set success to whether the call reverted. We don't expect return data.
            // We use 100 because the length of our calldata totals up like so: 4 + 32 * 4.
            success := call(gas(), approve2Address, 0, freeMemoryPointer, 130, 0, 0)
        }
    }
}
