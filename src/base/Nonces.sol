// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract Nonces {
    error NonceUsed();

    mapping(address => uint256) public nonces;
    mapping(address => mapping(uint248 => uint256)) public nonceBitmap;

    /// @notice Checks whether a nonce is taken. Then sets an increasing nonce on the from address.
    function _useNonce(address from, uint256 nonce) internal {
        if (nonce > nonces[from]) {
            revert NonceUsed();
        }
        nonces[from] = nonce;
    }

    /// @notice Checks whether a nonce is taken. Then sets the bit at the bitPos in the bitmap at the wordPos.
    function _useUnorderedNonce(address from, uint256 nonce) internal {
        (uint248 wordPos, uint8 bitPos) = bitmapPositions(nonce);
        uint256 bitmap = nonceBitmap[from][wordPos];
        if ((bitmap >> bitPos) & 1 == 1) {
            revert NonceUsed();
        }
        nonceBitmap[from][wordPos] = bitmap | (1 << bitPos);
    }

    /// @notice Invalidates the specified number of nonces.
    function invalidateNonces(uint256 amount) public {
        nonces[msg.sender] += amount;
    }

    /// @notice Invalidates the bits specified in `mask` for the bitmap at `wordPos`.
    function invalidateUnorderedNonces(uint248 wordPos, uint256 mask) public {
        nonceBitmap[msg.sender][wordPos] |= mask;
    }

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces.
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap.
    /// The last 8 bits of the nonce value is the position of the bit in the bitmap.
    function bitmapPositions(uint256 nonce) private pure returns (uint248 wordPos, uint8 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce & 255);
    }
}
