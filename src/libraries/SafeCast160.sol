// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library SafeCast160 {
    /// @notice Thrown when a value greater than type(uint160).max is cast to uint160
    error UnsafeCast();

    /// @notice Safely casts uint256 to uint160
    /// @param value The uint256 to be cast
    function toUint160(uint256 value) internal pure returns (uint160 result) {
        uint256 maxValue = type(uint160).max;
        assembly {
            if gt(value, maxValue) {
                mstore(0, 0xc4bd89a9)
                revert(0x1C, 0x04)
            }
            result := value
        }
    }
}
