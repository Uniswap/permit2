// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {SignatureTransfer} from "./SignatureTransfer.sol";

struct Permit {
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

contract Permit2 is SignatureTransfer {
    error NonceUsed();

    mapping(address => uint256) public nonces;
    mapping(address => mapping(uint248 => uint256)) public nonceBitmap;

    // TODO caching optimization w/chainId check
    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Permit2"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Checks whether a nonce is taken. Then sets an increasing nonce on the from address.
    function _useNonce(address from, uint256 nonce) internal override {
        if (nonce > nonces[from]) {
            revert NonceUsed();
        }
        nonces[from] = nonce;
    }

    /// @notice Checks whether a nonce is taken. Then sets the bit at the bitPos in the bitmap at the wordPos.
    function _useUnorderedNonce(address from, uint256 nonce) internal override {
        (uint248 wordPos, uint8 bitPos) = bitmapPositions(nonce);
        uint256 bitmap = nonceBitmap[from][wordPos];
        if ((bitmap >> bitPos) & 1 == 1) {
            revert NonceUsed();
        }
        nonceBitmap[from][wordPos] = bitmap | (1 << bitPos);
    }

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces.
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap.
    /// The last 8 bits of the nonce value is the position of the bit in the bitmap.
    function bitmapPositions(uint256 nonce) public pure returns (uint248 wordPos, uint8 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce & 255);
    }

    /// @notice Invalidates the specified number of nonces.
    function invalidateNonces(uint256 amount) public {
        nonces[msg.sender] += amount;
    }

    /// @notice Invalidates the bits specified in `mask` for the bitmap at `wordPos`.
    function invalidateUnorderedNonces(uint248 wordPos, uint256 mask) public {
        nonceBitmap[msg.sender][wordPos] |= mask;
    }
}
