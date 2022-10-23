// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice Shared errors between signature based transfers or allowance based transfers
error SignatureExpired();
error LengthMismatch();
error InvalidNonce();
