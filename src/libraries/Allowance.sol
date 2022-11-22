// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";

library Allowance {
    // note if the expiration passed is 0, then it the approval set to the block.timestamp
    uint256 private constant BLOCK_TIMESTAMP_EXPIRATION = 0;

    /// @notice Sets the allowed amount, expiry, and nonce of the spender's permissions on owner's token.
    /// @dev Nonce is incremented.
    /// @dev If the inputted expiration is 0, the stored expiration is set to block.timestamp
    function updateAll(
        IAllowanceTransfer.PackedAllowance storage allowed,
        uint160 amount,
        uint48 expiration,
        uint48 nonce
    ) internal {
        assembly {
            nonce := add(nonce, 1)
            let expiry
            switch expiration
            case 0 { expiry := timestamp() }
            default { expiry := expiration }
            let word := or(shl(208, nonce), or(shl(160, expiry), amount))
            sstore(allowed.slot, word)
        }
    }

    /// @notice Sets the allowed amount and expiry of the spender's permissions on owner's token.
    /// @dev Nonce does not need to be incremented.
    function updateAmountAndExpiration(
        IAllowanceTransfer.PackedAllowance storage allowed,
        uint160 amount,
        uint48 expiration
    ) internal {
        // If the inputted expiration is 0, the allowance only lasts the duration of the block.
        assembly {
            let expiry
            switch expiration
            case 0 { expiry := timestamp() }
            default { expiry := expiration }
            let slot := allowed.slot
            let word := sload(slot)
            sstore(slot, or(shl(208, shr(208, word)), or(shl(160, expiry), amount)))
        }
    }

    /// @notice Computes the packed slot of the amount, expiration, and nonce that make up PackedAllowance
    function pack(uint160 amount, uint48 expiration, uint48 nonce) internal pure returns (uint256 word) {
        word = (uint256(nonce) << 208) | uint256(expiration) << 160 | amount;
    }
}
