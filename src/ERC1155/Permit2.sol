// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransferERC1155} from "./SignatureTransferERC1155.sol";
import {AllowanceTransferERC1155} from "./AllowanceTransferERC1155.sol";

/// @notice Permit2 handles signature-based transfers in SignatureTransfer and allowance-based transfers in AllowanceTransfer.
/// @dev Users must approve Permit2 before calling any of the transfer functions.
contract Permit2ERC1155 is SignatureTransferERC1155, AllowanceTransferERC1155 {
// Permit2 unifies the two contracts so users have maximal flexibility with their approval.
}
