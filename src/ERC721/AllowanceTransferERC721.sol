// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "solmate/src/tokens/ERC721.sol";
import {PermitHashERC721} from "./libraries/PermitHashERC721.sol";
import {SignatureVerification} from "../shared/SignatureVerification.sol";
import {EIP712ERC721} from "./EIP712ERC721.sol";
import {IAllowanceTransferERC721} from "./interfaces/IAllowanceTransferERC721.sol";
import {SignatureExpired, InvalidNonce} from "../shared/PermitErrors.sol";
import {AllowanceERC721} from "./libraries/AllowanceERC721.sol";

contract AllowanceTransferERC721 is IAllowanceTransferERC721, EIP712ERC721 {
    using SignatureVerification for bytes;
    using PermitHashERC721 for PermitSingle;
    using PermitHashERC721 for PermitBatch;
    using PermitHashERC721 for PermitAll;
    using AllowanceERC721 for PackedAllowance;

    /// @notice Maps users to tokens to tokenId and information about the approval, including the approved spender, on the token
    /// @dev Indexed in the order of token owner address, token address, and tokenId
    /// @dev The stored word saves the allowed spender, expiration on the allowance, and nonce
    mapping(address => mapping(address => mapping(uint256 => PackedAllowance))) public allowance;

    /// @notice Maps users to tokens to spender and sets whether or not the spender has operator status on an entire token collection.
    /// @dev Indexed in the order of token owner address, token address, then spender address.
    /// @dev Sets a timestamp at which the spender no longer has operator status. Max expiration is type(uint48).max
    mapping(address => mapping(address => mapping(address => PackedOperatorAllowance))) public operators;

    /// @inheritdoc IAllowanceTransferERC721
    function approve(address token, address spender, uint256 tokenId, uint48 expiration) external {
        PackedAllowance storage allowed = allowance[msg.sender][token][tokenId];
        allowed.updateSpenderAndExpiration(spender, expiration);
        emit Approval(msg.sender, token, spender, tokenId, expiration);
    }

    /// @inheritdoc IAllowanceTransferERC721
    function setApprovalForAll(address token, address spender, uint48 expiration) external {
        operators[msg.sender][token][spender].expiration = expiration;
        emit ApprovalForAll(msg.sender, token, spender, expiration);
    }

    /// @inheritdoc IAllowanceTransferERC721
    function permit(address owner, PermitSingle memory permitSingle, bytes calldata signature) external {
        if (block.timestamp > permitSingle.sigDeadline) revert SignatureExpired(permitSingle.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitSingle.hash()), owner);

        _updateApproval(permitSingle.details, owner, permitSingle.spender);
    }

    /// @inheritdoc IAllowanceTransferERC721
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

    /// @inheritdoc IAllowanceTransferERC721
    function permit(address owner, PermitAll memory permitAll, bytes calldata signature) external {
        if (block.timestamp > permitAll.sigDeadline) revert SignatureExpired(permitAll.sigDeadline);

        // Verify the signer address from the signature.
        signature.verify(_hashTypedData(permitAll.hash()), owner);

        PackedOperatorAllowance storage operator = operators[owner][permitAll.token][permitAll.spender];

        if (permitAll.nonce != operator.nonce) revert InvalidNonce();

        unchecked {
            operator.nonce += 1;
        }
        operator.expiration = permitAll.expiration;
    }

    /// @inheritdoc IAllowanceTransferERC721
    function transferFrom(address from, address to, uint256 tokenId, address token) external {
        _transfer(from, to, tokenId, token);
    }

    /// @inheritdoc IAllowanceTransferERC721
    function transferFrom(AllowanceTransferDetails[] calldata transferDetails) external {
        unchecked {
            uint256 length = transferDetails.length;
            for (uint256 i = 0; i < length; ++i) {
                AllowanceTransferDetails memory transferDetail = transferDetails[i];
                _transfer(transferDetail.from, transferDetail.to, transferDetail.tokenId, transferDetail.token);
            }
        }
    }

    /// @notice Internal function for transferring tokens using stored allowances
    /// @dev msg.sender must have tokenId level permissions through the `allowance` mapping OR operator permissions through the `operators` mapping.
    /// @dev Will fail if the allowed timeframe has passed
    function _transfer(address from, address to, uint256 tokenId, address token) private {
        PackedAllowance storage allowed = allowance[from][token][tokenId];
        uint48 operatorExpiration = operators[from][token][msg.sender].expiration;
        bool operatorExpired = block.timestamp > operatorExpiration;

        // At least one of the approval methods must not be expired.
        if (block.timestamp > allowed.expiration && operatorExpired) {
            revert AllowanceExpired(allowed.expiration, operatorExpiration);
        }

        if (allowed.spender == msg.sender) {
            // Reset permissions before transfer.
            allowed.spender = address(0);
        } else if (operatorExpired) {
            // If there is no tokenId permissions and no operator permissions on msg.sender
            // then the msg.sender has insufficient allowance.
            revert InsufficientAllowance(token, tokenId);
        }

        // Transfer the token from the from address to the recipient.
        ERC721(token).safeTransferFrom(from, to, tokenId);
    }

    /// @inheritdoc IAllowanceTransferERC721
    function lockdown(TokenSpenderPair[] calldata operatorApprovals, TokenAndIdPair[] calldata tokenIdApprovals)
        external
    {
        address owner = msg.sender;
        // Revoke operator allowances for each pair of spenders and tokens.
        unchecked {
            uint256 length = operatorApprovals.length;
            for (uint256 i = 0; i < length; ++i) {
                address token = operatorApprovals[i].token;
                address spender = operatorApprovals[i].spender;

                operators[owner][token][spender].expiration = 0;
                emit Lockdown(owner, token, spender);
            }
        }
        // Revoke tokenId allowances for each pair of token and tokenId.
        unchecked {
            uint256 length = tokenIdApprovals.length;
            for (uint256 i = 0; i < length; ++i) {
                address token = tokenIdApprovals[i].token;
                uint256 tokenId = tokenIdApprovals[i].tokenId;
                allowance[owner][token][tokenId].expiration = 0;
            }
        }
    }

    /// @inheritdoc IAllowanceTransferERC721
    function invalidateNonces(address token, address spender, uint48 newNonce) external {
        uint48 oldNonce = operators[msg.sender][token][spender].nonce;

        if (newNonce <= oldNonce) revert InvalidNonce();

        // Limit the amount of nonces that can be invalidated in one transaction.
        unchecked {
            uint48 delta = newNonce - oldNonce;
            if (delta > type(uint16).max) revert ExcessiveInvalidation();
        }

        operators[msg.sender][token][spender].nonce = newNonce;
        emit NonceInvalidation(msg.sender, token, uint256(uint160(spender)), newNonce, oldNonce);
    }

    /// @inheritdoc IAllowanceTransferERC721
    function invalidateNonces(address token, uint256 tokenId, uint48 newNonce) external {
        uint48 oldNonce = allowance[msg.sender][token][tokenId].nonce;

        if (newNonce <= oldNonce) revert InvalidNonce();

        // Limit the amount of nonces that can be invalidated in one transaction.
        unchecked {
            uint48 delta = newNonce - oldNonce;
            if (delta > type(uint16).max) revert ExcessiveInvalidation();
        }

        allowance[msg.sender][token][tokenId].nonce = newNonce;
        emit NonceInvalidation(msg.sender, token, tokenId, newNonce, oldNonce);
    }

    /// @notice Sets the new values for tokenId, expiration, and nonce.
    /// @dev Will check that the signed nonce is equal to the current nonce and then incrememnt the nonce value by 1.
    /// @dev Emits a Permit event.
    function _updateApproval(PermitDetails memory details, address owner, address spender) private {
        uint48 nonce = details.nonce;
        address token = details.token;
        uint256 tokenId = details.tokenId;
        uint48 expiration = details.expiration;
        PackedAllowance storage allowed = allowance[owner][token][tokenId];

        if (allowed.nonce != nonce) revert InvalidNonce();

        allowed.updateAll(spender, expiration, nonce);
        emit Permit(owner, token, spender, tokenId, expiration, nonce);
    }
}
