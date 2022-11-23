// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {Permit2Lib} from "../../src/libraries/Permit2Lib.sol";

contract MockPermit2Lib {
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

    function transferFrom2(ERC20 token, address from, address to, uint256 amount) public {
        Permit2Lib.transferFrom2(token, from, to, amount);
    }

    function testPermit2Code(ERC20 token) external view returns (bool) {
        // Generate calldata for a call to DOMAIN_SEPARATOR on the token.
        bytes memory inputData = abi.encodeWithSelector(ERC20.DOMAIN_SEPARATOR.selector);

        bool success; // Call the token contract as normal, capturing whether it succeeded.
        bytes32 domainSeparator; // If the call succeeded, we'll capture the return value here.
        assembly {
            success :=
                and(
                    // Should resolve false if it returned <32 bytes or its first word is 0.
                    and(iszero(iszero(mload(0))), eq(returndatasize(), 32)),
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the and() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    staticcall(gas(), token, add(inputData, 32), mload(inputData), 0, 32)
                )

            domainSeparator := mload(0) // Copy the return value into the domainSeparator variable.
        }
        return success;
    }
}
