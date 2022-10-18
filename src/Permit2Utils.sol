pragma solidity 0.8.17;

struct Permit {
    address token;
    address spender;
    uint256 allowed;
    uint256 deadline;
    bytes32 witness;
}

struct PermitTransfer {
    SigType sigType;
    address token;
    address spender;
    uint256 maxAmount;
    uint256 deadline;
    uint256 nonce;
    bytes32 witness;
}

struct PermitBatch {
    SigType sigType;
    address[] tokens;
    address spender;
    uint256[] maxAmounts;
    uint256 deadline;
    uint256 nonce;
    bytes32 witness;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

enum SigType {
    ORDERED,
    UNORDERED
}

error InvalidSignature();
error DeadlinePassed();
error LengthMismatch();
error InvalidNonce();
error InsufficentAllowance();
