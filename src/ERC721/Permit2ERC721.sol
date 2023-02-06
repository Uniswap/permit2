// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransferERC721} from "./SignatureTransferERC721.sol";
import {AllowanceTransferERC721} from "./AllowanceTransferERC721.sol";

/// @notice Permit2 handles signature-based transfers in SignatureTransfer and allowance-based transfers in AllowanceTransfer.
/// @dev Users must approve Permit2 before calling any of the transfer functions.
/// @dev It is recommended that you set operator permissions on Permit2 by calling `setApprovalForAll` for any underlying ERC721 token.
contract Permit2ERC721 is SignatureTransferERC721, AllowanceTransferERC721 {
// Permit2 unifies the two contracts so users have maximal flexibility with their approval.
}
