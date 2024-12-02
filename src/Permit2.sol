// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SignatureTransfer} from "./SignatureTransfer.sol";
import {AllowanceTransfer} from "./AllowanceTransfer.sol";
import {FlashAllowanceTransfer} from "./FlashAllowanceTransfer.sol";

/// @notice Permit2 handles signature-based transfers in SignatureTransfer and allowance-based transfers in AllowanceTransfer.
/// @dev Users must approve Permit2 before calling any of the transfer functions.
contract Permit2 is SignatureTransfer, AllowanceTransfer, FlashAllowanceTransfer {
// Permit2 unifies the three contracts so users have maximal flexibility with their approval.
}
