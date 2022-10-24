// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {PermitHash} from "./libraries/PermitHash.sol";
import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {EIP712} from "./EIP712.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {SignatureExpired, LengthMismatch, InvalidNonce} from "./PermitErrors.sol";
import {Allowance} from "./libraries/Allowance.sol";

contract AllowanceTransfer is IAllowanceTransfer, EIP712 {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;
    using PermitHash for Permit;
    using PermitHash for PermitBatch;
    using Allowance for PackedAllowance;

    event InvalidateNonces(address indexed owner, uint32 indexed toNonce, address token, address spender);

    /// @notice Maps users to tokens to spender addresses and information about the approval on the token
    /// @dev Indexed in the order of token owner address, token address, spender address
    /// @dev The stored word saves the allowed amount, expiration on the allowance, and nonce
    mapping(address => mapping(address => mapping(address => PackedAllowance))) public allowance;

    /// @inheritdoc IAllowanceTransfer
    function approve(address token, address spender, uint160 amount, uint64 expiration) external {
        PackedAllowance storage allowed = allowance[msg.sender][token][spender];
        allowed.updateAmountAndExpiration(amount, expiration);
    }

    /// @inheritdoc IAllowanceTransfer
    function permit(Permit calldata permitData, address owner, bytes calldata signature) external {
        PackedAllowance storage allowed = allowance[owner][permitData.token][permitData.spender];
        _validatePermit(allowed.nonce, permitData.nonce, permitData.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitData.hash()), owner);

        // Increments the nonce, and sets the new values for amount and expiration.
        allowed.updateAll(permitData.amount, permitData.expiration, permitData.nonce);
    }

    /// @inheritdoc IAllowanceTransfer
    function permitBatch(PermitBatch calldata permitData, address owner, bytes calldata signature) external {
        // Use the first token's nonce.
        PackedAllowance storage allowed = allowance[owner][permitData.tokens[0]][permitData.spender];
        _validatePermit(allowed.nonce, permitData.nonce, permitData.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitData.hash()), owner);

        // Increments the nonce, and sets the new values for amount and expiration for the first token.
        allowed.updateAll(permitData.amounts[0], permitData.expirations[0], permitData.nonce);

        unchecked {
            for (uint256 i = 1; i < permitData.tokens.length; ++i) {
                allowed = allowance[owner][permitData.tokens[i]][permitData.spender];
                allowed.updateAmountAndExpiration(permitData.amounts[i], permitData.expirations[i]);
            }
        }
    }

    /// @notice Ensures that the deadline on the signature has not passed, and that the nonce hasn't been used
    function _validatePermit(uint32 nonce, uint32 signedNonce, uint256 sigDeadline) private view {
        if (block.timestamp > sigDeadline) revert SignatureExpired();
        if (nonce != signedNonce) revert InvalidNonce();
    }

    /// @inheritdoc IAllowanceTransfer
    function transferFrom(address token, address from, address to, uint160 amount) external {
        _transfer(token, from, to, amount);
    }

    /// @inheritdoc IAllowanceTransfer
    function batchTransferFrom(
        address[] calldata tokens,
        address from,
        address[] calldata to,
        uint160[] calldata amounts
    ) external {
        if (amounts.length != to.length || tokens.length != to.length) revert LengthMismatch();

        unchecked {
            for (uint256 i = 0; i < tokens.length; ++i) {
                _transfer(tokens[i], from, to[i], amounts[i]);
            }
        }
    }

    /// @notice Internal function for transferring tokens using stored allowances
    /// @dev Will fail if the allowed timeframe has passed
    function _transfer(address token, address from, address to, uint160 amount) private {
        PackedAllowance storage allowed = allowance[from][token][msg.sender];

        if (block.timestamp > allowed.expiration) revert AllowanceExpired();

        uint256 maxAmount = allowed.amount;
        if (maxAmount != type(uint160).max) {
            if (amount > maxAmount) {
                revert InsufficientAllowance();
            } else {
                unchecked {
                    allowed.amount -= amount;
                }
            }
        }

        // Transfer the tokens from the from address to the recipient.
        ERC20(token).safeTransferFrom(from, to, amount);
    }

    /// @inheritdoc IAllowanceTransfer
    function lockdown(address[] calldata tokens, address[] calldata spenders) external {
        // Each index should correspond to an index in the other array.
        if (tokens.length != spenders.length) revert LengthMismatch();

        // Revoke allowances for each pair of spenders and tokens.
        unchecked {
            for (uint256 i = 0; i < spenders.length; ++i) {
                allowance[msg.sender][tokens[i]][spenders[i]].amount = 0;
            }
        }
    }

    /// @inheritdoc IAllowanceTransfer
    function invalidateNonces(address token, address spender, uint32 amountToInvalidate)
        public
        returns (uint32 newNonce)
    {
        if (amountToInvalidate > type(uint16).max) revert ExcessiveInvalidation();

        unchecked {
            // Overflow is impossible on human timescales.
            newNonce = allowance[msg.sender][token][spender].nonce += amountToInvalidate;
        }

        emit InvalidateNonces(msg.sender, newNonce, token, spender);
    }
}
