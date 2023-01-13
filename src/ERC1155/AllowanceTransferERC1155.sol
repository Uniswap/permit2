// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PermitHashERC1155} from "./libraries/PermitHashERC1155.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";
import {SignatureVerification} from "../shared/SignatureVerification.sol";
import {EIP712ForERC1155} from "./EIP712ForERC1155.sol";
import {IAllowanceTransferERC1155} from "./interfaces/IAllowanceTransferERC1155.sol";
import {SignatureExpired, InvalidNonce} from "../shared/PermitErrors.sol";
import {AllowanceERC1155} from "./libraries/AllowanceERC1155.sol";

contract AllowanceTransferERC1155 is IAllowanceTransferERC1155, EIP712ForERC1155 {
    using SignatureVerification for bytes;
    using PermitHashERC1155 for PermitSingle;
    using PermitHashERC1155 for PermitBatch;
    using PermitHashERC1155 for PermitAll;
    using AllowanceERC1155 for PackedAllowance;

    /// @notice Maps users to tokens to spender addresses and information about the approval on the token
    /// @dev Indexed in the order of token owner address, token address, spender address, tokenId
    /// @dev The stored word saves the allowed amount of the tokenId, expiration on the allowance, and nonce
    mapping(address => mapping(address => mapping(address => mapping(uint256 => PackedAllowance)))) public allowance;

    /// @notice Maps users to tokens to spender and sets whether or not the spender has operator status on an entire token collection.
    /// @dev Indexed in the order of token owner address, token address, then spender address.
    /// @dev Sets a timestamp at which the spender no longer has operator status. Max expiration is type(uint48).max
    mapping(address => mapping(address => mapping(address => PackedOperatorAllowance))) public operators;

    /// @inheritdoc IAllowanceTransferERC1155
    function approve(address token, address spender, uint160 amount, uint256 tokenId, uint48 expiration) external {
        PackedAllowance storage allowed = allowance[msg.sender][token][spender][tokenId];
        allowed.updateAmountAndExpiration(amount, expiration);
        emit Approval(msg.sender, token, spender, tokenId, amount, expiration);
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function setApprovalForAll(address token, address spender, uint48 expiration) external {
        operators[msg.sender][token][spender].expiration = expiration;
        emit ApprovalForAll(msg.sender, token, spender, expiration);
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function permit(address owner, PermitSingle memory permitSingle, bytes calldata signature) external {
        if (block.timestamp > permitSingle.sigDeadline) revert SignatureExpired(permitSingle.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitSingle.hash()), owner);

        _updateApproval(permitSingle.details, owner, permitSingle.spender);
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function permit(address owner, PermitBatch memory permitBatch, bytes calldata signature) external {
        if (block.timestamp > permitBatch.sigDeadline) revert SignatureExpired(permitBatch.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitBatch.hash()), owner);

        address spender = permitBatch.spender;
        unchecked {
            uint256 length = permitBatch.details.length;
            for (uint256 i = 0; i < length; ++i) {
                _updateApproval(permitBatch.details[i], owner, spender);
            }
        }
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function permit(address owner, PermitAll memory permitAll, bytes calldata signature) external {
        if (block.timestamp > permitAll.sigDeadline) revert SignatureExpired(permitAll.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitAll.hash()), owner);

        PackedOperatorAllowance storage operator = operators[owner][permitAll.token][permitAll.spender];
        if (operator.nonce != permitAll.nonce) revert InvalidNonce();

        unchecked {
            operator.nonce += 1;
        }
        operator.expiration = permitAll.expiration;
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function transferFrom(address from, address to, uint256 tokenId, uint160 amount, address token) external {
        _transfer(from, to, tokenId, amount, token);
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function transferFrom(AllowanceTransferDetails[] calldata transferDetails) external {
        unchecked {
            uint256 length = transferDetails.length;
            for (uint256 i = 0; i < length; ++i) {
                AllowanceTransferDetails memory transferDetail = transferDetails[i];
                _transfer(
                    transferDetail.from,
                    transferDetail.to,
                    transferDetail.tokenId,
                    transferDetail.amount,
                    transferDetail.token
                );
            }
        }
    }

    /// @notice Internal function for transferring tokens using stored allowances
    /// @dev Will fail if the allowed timeframe has passed
    function _transfer(address from, address to, uint256 tokenId, uint160 amount, address token) private {
        PackedAllowance storage allowed = allowance[from][token][msg.sender][tokenId];

        PackedOperatorAllowance storage operator = operators[from][token][msg.sender];
        bool operatorExpired = block.timestamp > operator.expiration;

        // At least one of the approval methods must not be expired.
        if (block.timestamp > allowed.expiration && operatorExpired) {
            revert AllowanceExpired(allowed.expiration, operator.expiration);
        }

        uint256 maxAmount = allowed.amount;

        if (maxAmount != type(uint160).max && amount < maxAmount) {
            unchecked {
                allowed.amount = uint160(maxAmount) - amount;
            }
        } else if (operatorExpired) {
            // Only revert if there is also not a valid approval on the operator mapping.
            // Otherwise, the spender is an operator & can transfer any amount of any tokenId in the collection.
            revert InsufficientAllowance(maxAmount);
        }

        // Transfer the tokens from the from address to the recipient.
        ERC1155(token).safeTransferFrom(from, to, tokenId, amount, "");
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function lockdown(TokenSpenderPair[] calldata operatorApprovals, TokenSpenderTokenId[] calldata tokenIdApprovals)
        external
    {
        address owner = msg.sender;

        unchecked {
            // Revoke operator allowances for each pair of spenders and tokens.
            uint256 length = operatorApprovals.length;
            for (uint256 i = 0; i < length; ++i) {
                address token = operatorApprovals[i].token;
                address spender = operatorApprovals[i].spender;

                operators[owner][token][spender].expiration = 0;
                emit Lockdown(owner, token, spender);
            }
        }

        unchecked {
            // Revoke tokenId allowances for each tuple of token, spender, and tokenId.
            uint256 length = tokenIdApprovals.length;
            for (uint256 i = 0; i < length; i++) {
                address token = tokenIdApprovals[i].token;
                address spender = tokenIdApprovals[i].spender;
                uint256 tokenId = tokenIdApprovals[i].tokenId;
                allowance[owner][token][spender][tokenId].amount = 0;
            }
        }
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function invalidateNonces(address token, address spender, uint256 tokenId, uint48 newNonce) external {
        uint48 oldNonce = allowance[msg.sender][token][spender][tokenId].nonce;

        if (newNonce <= oldNonce) revert InvalidNonce();

        // Limit the amount of nonces that can be invalidated in one transaction.
        unchecked {
            uint48 delta = newNonce - oldNonce;
            if (delta > type(uint16).max) revert ExcessiveInvalidation();
        }

        allowance[msg.sender][token][spender][tokenId].nonce = newNonce;
        emit NonceInvalidation(msg.sender, token, spender, tokenId, newNonce, oldNonce);
    }

    /// @inheritdoc IAllowanceTransferERC1155
    function invalidateNonces(address token, address spender, uint48 newNonce) external {
        uint48 oldNonce = operators[msg.sender][token][spender].nonce;

        if (newNonce <= oldNonce) revert InvalidNonce();

        // Limit the amount of nonces that can be invalidated in one transaction.
        unchecked {
            uint48 delta = newNonce - oldNonce;
            if (delta > type(uint16).max) revert ExcessiveInvalidation();
        }

        operators[msg.sender][token][spender].nonce = newNonce;
        emit NonceInvalidation(msg.sender, token, spender, newNonce, oldNonce);
    }

    /// @notice Sets the new values for amount, expiration, and nonce.
    /// @dev Will check that the signed nonce is equal to the current nonce and then incrememnt the nonce value by 1.
    /// @dev Emits a Permit event.
    function _updateApproval(PermitDetails memory details, address owner, address spender) private {
        uint48 nonce = details.nonce;
        address token = details.token;
        uint160 amount = details.amount;
        uint256 tokenId = details.tokenId;
        uint48 expiration = details.expiration;

        PackedAllowance storage allowed = allowance[owner][token][spender][tokenId];

        if (allowed.nonce != nonce) revert InvalidNonce();

        allowed.updateAll(amount, expiration, nonce);
        emit Permit(owner, token, spender, amount, expiration, nonce);
    }
}
