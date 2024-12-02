// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IAllowanceTransfer.sol";

/// @title AllowanceTransfer
/// @notice Handles ERC20 token permissions through signature based allowance setting and ERC20 token transfers by checking allowed amounts
/// @dev Requires user's token approval on the Permit2 contract
interface IFlashAllowanceTransfer {
    /// @notice Approves the spender to use up to amount of the specified token
    /// @param token The token to approve
    /// @param spender The spender address to approve
    /// @param amount The approved amount of the token
    /// @dev Setting amount to type(uint160).max sets an unlimited approval
    function flashApprove(address token, address spender, uint256 amount) external;

    /// @notice Transfer approved tokens from one address to another
    /// @param from The address to transfer from
    /// @param to The address of the recipient
    /// @param amount The amount of the token to transfer
    /// @param token The token address to transfer
    /// @dev Requires the from address to have approved at least the desired amount
    /// of tokens to msg.sender.
    function flashTransferFrom(address from, address to, uint256 amount, address token) external;

    /// @notice Transfer approved tokens in a batch
    /// @param transferDetails Array of owners, recipients, amounts, and tokens for the transfers
    /// @dev Requires the from addresses to have approved at least the desired amount
    /// of tokens to msg.sender.
    function flashTransferFrom(IAllowanceTransfer.AllowanceTransferDetails[] calldata transferDetails) external;
}
