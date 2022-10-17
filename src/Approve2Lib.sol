// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";
import {Approve2} from "./Approve2.sol";

// TODO: Clobber slots instead of using the free memory pointer.

/// @title Approve2Lib
/// @author transmissions11 <t11s@paradigm.xyz>
/// @notice Enables efficient transfers and EIP-2612/DAI
/// permits for any token by falling back to Approve2.
library Approve2Lib {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The unique EIP-712 domain domain separator for the DAI token contract.
    bytes32 internal constant DAI_DOMAIN_SEPARATOR = 0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;

    /// @dev The address of the Approve2 contract the library will use.
    bytes32 internal constant APPROVE2_ADDRESS = 0x000000000000000000000000ce71065d4017f316ec606fe4422e11eb2c47c246;

    /*//////////////////////////////////////////////////////////////
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer a given amount of tokens from one user to another.
    /// @param token The token to transfer.
    /// @param from The user to transfer from.
    /// @param to The user to transfer to.
    /// @param amount The amount to transfer.
    function transferFrom2(ERC20 token, address from, address to, uint256 amount) internal {
        assembly {
            /*//////////////////////////////////////////////////////////////
                              ATTEMPT SAFE TRANSFER FROM
            //////////////////////////////////////////////////////////////*/

            // We'll write some calldata to this slot below, but restore it later.
            let memPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(0, 0x23b872dd) // 0x23b872dd is the function selector for transferFrom.
            mstore(32, from) // Append the "from" argument.
            mstore(64, to) // Append the "to" argument.
            mstore(96, amount) // Append the "amount" argument.

            // If the call to transferFrom fails for any reason, try using Approve2.
            if iszero(
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0), 1), iszero(returndatasize())),
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    // We use 0 and 28 because our calldata begins with the last 4 bytes of the first slot.
                    // We use 100 because the length of our generated calldata totals up like so: 4 + 32 * 3.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the first slot of scratch space.
                    call(gas(), token, 0, 28, 100, 0, 32)
                )
            ) {
                /*//////////////////////////////////////////////////////////////
                                      FALLBACK TO APPROVE2
                //////////////////////////////////////////////////////////////*/

                // We'll write some calldata to this slot below, but restore it later.
                let memSlot128 := mload(128)

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(0, 0x15dacbea) // 0x15dacbea is the function selector for Approve2's transferFrom.
                mstore(32, token) // Append the "token" argument.
                mstore(64, from) // Append the "from" argument.
                mstore(96, to) // Append the "to" argument.
                mstore(128, amount) // Append the "amount" argument.

                // We use 0 and 28 because our calldata begins with the last 4 bytes of the first slot.
                // We use 132 because the length of our generated calldata totals up like so: 4 + 32 * 4.
                if iszero(call(gas(), APPROVE2_ADDRESS, 0, 28, 132, 0, 0)) {
                    // Bubble up any revert reasons returned.
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                mstore(128, memSlot128) // Restore slot 128.
            }

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, memPointer) // Restore the memPointer.
        }
    }

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
    ) internal {
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning
            // with the function selector for EIP-2612 DOMAIN_SEPARATOR.
            mstore(freeMemoryPointer, 0x3644e51500000000000000000000000000000000000000000000000000000000)

            let success :=
                and(
                    // Should resolve false if it returned <32 bytes or its first word is 0.
                    and(iszero(iszero(mload(0))), gt(returndatasize(), 31)),
                    // We use 4 because our calldata is just a single 4 byte function selector.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the and() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    call(gas(), token, 0, freeMemoryPointer, 4, 0, 32)
                )

            // If the call to DOMAIN_SEPARATOR succeeded, try using permit on the token.
            if success {
                // If the token's selector matches DAI's, it requires
                // special logic, otherwise we can use EIP-2612 permit.
                switch eq(mload(0), DAI_DOMAIN_SEPARATOR)
                case 0 {
                    /*//////////////////////////////////////////////////////////////
                                          STANDARD PERMIT LOGIC
                    //////////////////////////////////////////////////////////////*/

                    // Write the abi-encoded calldata into memory, beginning with the function selector.
                    mstore(freeMemoryPointer, 0xd505accf00000000000000000000000000000000000000000000000000000000)
                    mstore(add(freeMemoryPointer, 4), owner) // Append the "owner" argument.
                    mstore(add(freeMemoryPointer, 36), spender) // Append the "spender" argument.
                    mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.
                    mstore(add(freeMemoryPointer, 100), deadline) // Append the "deadline" argument.
                    mstore(add(freeMemoryPointer, 132), v) // Append the "v" argument.
                    mstore(add(freeMemoryPointer, 164), r) // Append the "r" argument.
                    mstore(add(freeMemoryPointer, 196), s) // Append the "s" argument.

                    // We use 228 because the length of our calldata totals up like so: 4 + 32 * 7.
                    success := call(gas(), token, 0, freeMemoryPointer, 228, 0, 0)
                }
                case 1 {
                    /*//////////////////////////////////////////////////////////////
                                          NONCE RETRIEVAL LOGIC
                    //////////////////////////////////////////////////////////////*/

                    // Write the abi-encoded calldata into memory, beginning with the function selector.
                    mstore(freeMemoryPointer, 0x7ecebe0000000000000000000000000000000000000000000000000000000000)
                    mstore(add(freeMemoryPointer, 4), owner) // Append the "owner" argument.

                    // We use 36 because the length of our calldata totals up like so: 4 + 32.
                    // We use 0 and 32 to copy up to 32 bytes of return data into scratch space.
                    pop(call(gas(), token, 0, freeMemoryPointer, 36, 0, 32))

                    /*//////////////////////////////////////////////////////////////
                                            DAI PERMIT LOGIC
                    //////////////////////////////////////////////////////////////*/

                    // Write the abi-encoded calldata into memory, beginning with the function selector.
                    mstore(freeMemoryPointer, 0x8fcbaf0c00000000000000000000000000000000000000000000000000000000)
                    mstore(add(freeMemoryPointer, 4), owner) // Append the "owner" argument.
                    mstore(add(freeMemoryPointer, 36), spender) // Append the "spender" argument.
                    mstore(add(freeMemoryPointer, 68), mload(0)) // Append the "nonce" argument.
                    mstore(add(freeMemoryPointer, 100), deadline) // Append the "deadline" argument.
                    mstore(add(freeMemoryPointer, 132), 1) // Append the "allowed" argument.
                    mstore(add(freeMemoryPointer, 164), v) // Append the "v" argument.
                    mstore(add(freeMemoryPointer, 196), r) // Append the "r" argument.
                    mstore(add(freeMemoryPointer, 228), s) // Append the "s" argument.

                    // We use 260 because the length of our calldata totals up like so: 4 + 32 * 8.
                    success := call(gas(), token, 0, freeMemoryPointer, 260, 0, 0)
                }
            }

            // If the initial DOMAIN_SEPARATOR call on the token failed or a
            // subsequent call to permit failed, fall back to using Approve2.
            if iszero(success) {
                /*//////////////////////////////////////////////////////////////
                                     APPROVE2 FALLBACK LOGIC
                //////////////////////////////////////////////////////////////*/

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(freeMemoryPointer, 0xd339056d00000000000000000000000000000000000000000000000000000000)
                mstore(add(freeMemoryPointer, 4), token) // Append the "token" argument.
                mstore(add(freeMemoryPointer, 36), owner) // Append the "owner" argument.
                mstore(add(freeMemoryPointer, 68), spender) // Append the "spender" argument.
                mstore(add(freeMemoryPointer, 100), amount) // Append the "amount" argument.
                mstore(add(freeMemoryPointer, 132), deadline) // Append the "deadline" argument.
                mstore(add(freeMemoryPointer, 164), v) // Append the "v" argument.
                mstore(add(freeMemoryPointer, 196), r) // Append the "r" argument.
                mstore(add(freeMemoryPointer, 228), s) // Append the "s" argument.

                // We use 260 because the length of our calldata totals up like so: 4 + 32 * 8.
                if iszero(call(gas(), APPROVE2_ADDRESS, 0, freeMemoryPointer, 260, 0, 0)) {
                    // Bubble up any revert reasons returned.
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }
}
