// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Approve2} from "./Approve2.sol";

// TODO: DAI special case

library Approve2Lib {
    using SafeTransferLib for ERC20;

    function permit2(
        ERC20 token,
        Approve2 approve2,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // TODO: idt the returndata decoding for nonce will be caught, should test with weth

        // Get and cache the starting nonce.
        try token.nonces(owner) returns (uint256 nonce) {
            // Attempt to call permit on the token.
            try token.permit(owner, spender, value, deadline, v, r, s) {} catch {
                // If permit didn't work, then we need to check if the owner is the spender.
                if (token.nonces(owner) != nonce + 1) approve2.permit(owner, spender, value, deadline, v, r, s);
            }
        } catch {
            // If there is no nonce function, go straight to Approve2.
            approve2.permit(owner, spender, value, deadline, v, r, s);
        }
    }

    function transferFrom2(
        ERC20 token,
        Approve2 permit,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (safeTransferFrom)
            if (token.allowance(from, address(this)) >= amount) {
                // Use normal transfer if possible.
                token.safeTransferFrom(from, to, amount);
            } else {
                // Otherwise try Approve2 (assume permit has already happened).
                permit.transferFrom(token, from, to, amount);
            }
    }

    /*//////////////////////////////////////////////////////////////
                           SAFE TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

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
}
