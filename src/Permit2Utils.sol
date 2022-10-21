// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct PackedAllowance {
    uint160 amount;
    uint64 expiration;
    uint32 nonce;
}

struct Permit {
    address token;
    address spender;
    uint160 amount;
    uint64 expiration;
    uint32 nonce;
    uint256 sigDeadline;
}

struct PermitTransfer {
    address token;
    address spender;
    uint256 signedAmount;
    uint256 nonce;
    uint256 deadline;
}

struct PermitBatchTransfer {
    address[] tokens;
    address spender;
    uint256[] signedAmounts;
    uint256 nonce;
    uint256 deadline;
}

struct PermitWitnessTransfer {
    address token;
    address spender;
    uint256 signedAmount;
    uint256 nonce;
    uint256 deadline;
    bytes32 witness;
}

error InvalidSignature();
error LengthMismatch();
error InvalidNonce();
error InsufficientAllowance();
error SignatureExpired();
error AllowanceExpired();
error NotSpender();
error InvalidAmount();
error ExcessiveInvalidation();
error SignedDetailsLengthMismatch();
error AmountsLengthMismatch();
error RecipientLengthMismatch();
