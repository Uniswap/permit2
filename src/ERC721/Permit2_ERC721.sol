// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransfer_ERC721} from "./SignatureTransfer_ERC721.sol";
import {AllowanceTransfer_ERC721} from "./AllowanceTransfer_ERC721.sol";

/// @notice Permit2 handles signature-based transfers in SignatureTransfer and allowance-based transfers in AllowanceTransfer.
/// @dev Users must approve Permit2 before calling any of the transfer functions.
/// @dev It is recommended that you set operator permissions on Permit2 by calling `setApprovalForAll` for any underlying ERC721 token.
contract Permit2_ERC721 is SignatureTransfer_ERC721, AllowanceTransfer_ERC721 {
// Permit2 unifies the two contracts so users have maximal flexibility with their approval.
}
