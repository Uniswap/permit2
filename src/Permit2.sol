// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransfer} from "./SignatureTransfer.sol";
import {AllowanceTransfer} from "./AllowanceTransfer.sol";

contract Permit2 is SignatureTransfer, AllowanceTransfer {
// Permit2 handles signature-based transfers in SignatureTransfer and allowance-based transfers in AllowanceTransfer.
// Permit2 unifies them so users have maximal flexibility with their approval.
}
