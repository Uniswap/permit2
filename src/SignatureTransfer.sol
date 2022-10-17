// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Permit, Signature, PermitBatch, SigType, InvalidSignature, DeadlinePassed} from "./Permit2Utils.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

abstract contract SignatureTransfer {
    error NotSpender();
    error InvalidAmount();

    /// @dev sigType field distinguishes between using unordered nonces or ordered nonces for replay protection
    bytes32 public constant _PERMIT_TRANSFER_TYPEHASH = keccak256(
        "PermitTransferFrom(uint8 sigType,address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(uint8 sigType,address[] tokens,address spender,uint256[] maxAmounts,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32);
    function _useNonce(address from, uint256 nonce) internal virtual;
    function _useUnorderedNonce(address from, uint256 nonce) internal virtual;

    /// @notice Transfers a token using a signed permit message.
    /// @dev If to is the zero address, the tokens are sent to the spender.
    /// Can use ordered or unordered nonces for replay protection.
    function permitTransferFrom(Permit calldata permit, address to, uint256 amount, Signature calldata sig)
        public
        returns (address signer)
    {
        // TODO potentially use sep validation for amounts, test gas
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory maxAmounts = new uint256[](1);

        amounts[0] = amount;
        maxAmounts[0] = permit.maxAmount;
        _validatePermit(permit.spender, permit.deadline, maxAmounts, amounts);

        signer = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            _PERMIT_TRANSFER_TYPEHASH,
                            permit.sigType,
                            permit.token,
                            permit.spender,
                            permit.maxAmount,
                            permit.nonce,
                            permit.deadline,
                            permit.witness
                        )
                    )
                )
            ),
            sig.v,
            sig.r,
            sig.s
        );

        if (signer == address(0)) {
            revert InvalidSignature();
        }

        if (permit.sigType == SigType.ORDERED) {
            _useNonce(signer, permit.nonce);
        } else if (permit.sigType == SigType.UNORDERED) {
            _useUnorderedNonce(signer, permit.nonce);
        }

        if (to == address(0)) {
            ERC20(permit.token).transferFrom(signer, permit.spender, amount);
        } else {
            ERC20(permit.token).transferFrom(signer, to, amount);
        }
    }

    function permitBatchTransferFrom(
        PermitBatch calldata permit,
        address[] calldata to,
        uint256[] calldata amounts,
        Signature calldata sig
    ) public returns (address signer) {
        _validatePermit(permit.spender, permit.deadline, permit.maxAmounts, amounts);

        signer = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            _PERMIT_BATCH_TRANSFER_TYPEHASH,
                            permit.sigType,
                            keccak256(abi.encodePacked(permit.tokens)),
                            permit.spender,
                            keccak256(abi.encodePacked(permit.maxAmounts)),
                            permit.nonce,
                            permit.deadline,
                            permit.witness
                        )
                    )
                )
            ),
            sig.v,
            sig.r,
            sig.s
        );

        if (signer == address(0)) {
            revert InvalidSignature();
        }

        if (permit.sigType == SigType.ORDERED) {
            _useNonce(signer, permit.nonce);
        } else if (permit.sigType == SigType.UNORDERED) {
            _useUnorderedNonce(signer, permit.nonce);
        }

        if (to.length == 1) {
            // send all tokens to the same recipient address if only one is specified
            // address recipient = to[0];
            for (uint256 i = 0; i < permit.tokens.length; ++i) {
                ERC20(permit.tokens[i]).transferFrom(signer, to[0], amounts[i]);
            }
        } else {
            for (uint256 i = 0; i < permit.tokens.length; ++i) {
                ERC20(permit.tokens[i]).transferFrom(signer, to[i], amounts[i]);
            }
        }
    }

    function _validatePermit(address spender, uint256 deadline, uint256[] memory maxAmounts, uint256[] memory amounts)
        internal
        view
    {
        if (msg.sender != spender) {
            revert NotSpender();
        }
        if (block.timestamp > deadline) {
            revert DeadlinePassed();
        }

        for (uint256 i = 0; i < amounts.length; ++i) {
            if (amounts[i] > maxAmounts[i]) {
                revert InvalidAmount();
            }
        }
    }
}
