pragma solidity 0.8.17;

struct Permit {
    address token;
    address spender;
    uint160 amount;
    uint64 expiration;
    uint256 sigDeadline;
    bytes32 witness;
}

struct PackedAllowance {
    uint160 amount;
    uint64 expiration;
    uint32 nonce;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

error InvalidSignature();
error DeadlinePassed();
error LengthMismatch();
error InvalidNonce();
error InsufficentAllowance();
error SignatureExpired();
error AllowanceExpired();
