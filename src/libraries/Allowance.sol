// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";

library Allowance {
    /// @notice Sets the allowed amount, expiry, and nonce of the spender's permissions on owner's token.
    /// @dev Nonce is incremented.
    /// @dev If the inputted expiration is 0, the stored expiration is set to block.timestamp
    function updateAll(
        IAllowanceTransfer.PackedAllowance storage allowed,
        uint160 amount,
        uint48 expiration,
        uint48 nonce
    ) internal {
        uint48 storedNonce;
        unchecked {
            storedNonce = nonce + 1;
        }

        uint48 storedExpiration = expiration == 0 ? uint48(block.timestamp) : expiration;

        uint256 word = pack(amount, storedExpiration, storedNonce);
        assembly {
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
        allowed.expiration = expiration == 0 ? uint48(block.timestamp) : expiration;
        allowed.amount = amount;
    }

    /// @notice Computes the packed slot of the amount, expiration, and nonce that make up PackedAllowance
    function pack(uint160 amount, uint48 expiration, uint48 nonce) internal pure returns (uint256 word) {
        word = (uint256(nonce) << 208) | uint256(expiration) << 160 | amount;
    }
}
