// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {Permit2Lib} from "../../src/libraries/Permit2Lib.sol";

contract MockPermit2Lib {
    /// @dev The address for the WETH9 contract on Ethereum mainnet, encoded as a bytes32.
    bytes32 internal constant WETH9_ADDRESS = 0x000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;

    function permit2(
        ERC20 token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        Permit2Lib.permit2(token, owner, spender, amount, deadline, v, r, s);
    }

    function simplePermit2(
        ERC20 token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        Permit2Lib.simplePermit2(token, owner, spender, amount, deadline, v, r, s);
    }

    function transferFrom2(ERC20 token, address from, address to, uint256 amount) public {
        Permit2Lib.transferFrom2(token, from, to, amount);
    }

    function testPermit2Code(ERC20 token) external view returns (bool) {
        // Generate calldata for a call to DOMAIN_SEPARATOR on the token.
        bytes memory inputData = abi.encodeWithSelector(ERC20.DOMAIN_SEPARATOR.selector);

        bool success; // Call the token contract as normal, capturing whether it succeeded.
        bytes32 domainSeparator; // If the call succeeded, we'll capture the return value here.
        assembly {
            // If the token is WETH9, we know it doesn't have a DOMAIN_SEPARATOR, and we'll skip this step.
            // We make sure to mask the token address as its higher order bits aren't guaranteed to be clean.
            if iszero(eq(and(token, 0xffffffffffffffffffffffffffffffffffffffff), WETH9_ADDRESS)) {
                success :=
                    and(
                        // Should resolve false if its not 32 bytes or its first word is 0.
                        and(iszero(iszero(mload(0))), eq(returndatasize(), 32)),
                        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                        // Counterintuitively, this call must be positioned second to the and() call in the
                        // surrounding and() call or else returndatasize() will be zero during the computation.
                        // We send a maximum of 5000 gas to prevent tokens with fallbacks from using a ton of gas.
                        // which should be plenty to allow tokens to fetch their DOMAIN_SEPARATOR from storage, etc.
                        staticcall(5000, token, add(inputData, 32), mload(inputData), 0, 32)
                    )

                domainSeparator := mload(0) // Copy the return value into the domainSeparator variable.
            }
        }
        return success;
    }
}
