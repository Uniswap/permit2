// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Permit2} from "../../src/Permit2.sol";
import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";
import {Allowance} from "../../src/libraries/Allowance.sol";

contract MockPermit2 is Permit2 {
    function setAllowance(address from, address token, address spender, uint48 nonce)
        public
        returns (IAllowanceTransfer.PackedAllowance memory allowed)
    {
        allowed = allowance[from][token][spender];
        allowance[from][token][spender].nonce = nonce;
    }

    function doStore(address from, address token, address spender, uint256 word) public {
        IAllowanceTransfer.PackedAllowance storage allowed = allowance[from][token][spender];
        assembly {
            sstore(allowed.slot, word)
        }
    }

    function getStore(address from, address token, address spender) public view returns (uint256 word) {
        IAllowanceTransfer.PackedAllowance storage allowed = allowance[from][token][spender];
        assembly {
            word := sload(allowed.slot)
        }
    }

    function testUpdateAll(
        address from,
        address token,
        address spender,
        uint160 amount,
        uint48 expiration,
        uint48 nonce
    ) public {
        IAllowanceTransfer.PackedAllowance storage allowed = allowance[from][token][spender];
        Allowance.updateAll(allowed, amount, expiration, nonce);
    }

    function useUnorderedNonce(address from, uint256 nonce) public {
        _useUnorderedNonce(from, nonce);
    }

    function testBitmapPositions(uint256 nonce) public pure returns (uint256 wordPos, uint256 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce);
    }

    function testInvalidateUnorderedNonces(uint256 wordPos, uint256 mask) public {
        invalidateUnorderedNonces(wordPos, mask);
    }
}
