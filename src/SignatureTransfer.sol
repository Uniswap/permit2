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
    function permitTransferFrom(Permit calldata permitData, address to, uint256 amount, Signature calldata sig)
        public
        returns (address signer)
    {
        // TODO potentially use sep validation for amounts, test gas
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory maxAmounts = new uint256[](1);

        amounts[0] = amount;
        maxAmounts[0] = permitData.maxAmount;
        _validatePermit(permitData.spender, permitData.deadline, maxAmounts, amounts);

        signer = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            _PERMIT_TRANSFER_TYPEHASH,
                            permitData.sigType,
                            permitData.token,
                            permitData.spender,
                            permitData.maxAmount,
                            permitData.nonce,
                            permitData.deadline,
                            permitData.witness
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

        if (permitData.sigType == SigType.ORDERED) {
            _useNonce(signer, permitData.nonce);
        } else if (permitData.sigType == SigType.UNORDERED) {
            _useUnorderedNonce(signer, permitData.nonce);
        }

        if (to == address(0)) {
            ERC20(permitData.token).transferFrom(signer, permitData.spender, amount);
        } else {
            ERC20(permitData.token).transferFrom(signer, to, amount);
        }
    }

    function permitBatchTransferFrom(
        PermitBatch calldata permitData,
        address[] calldata to,
        uint256[] calldata amounts,
        Signature calldata sig
    ) public returns (address signer) {
        _validatePermit(permitData.spender, permitData.deadline, permitData.maxAmounts, amounts);

        signer = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            _PERMIT_BATCH_TRANSFER_TYPEHASH,
                            permitData.sigType,
                            keccak256(abi.encodePacked(permitData.tokens)),
                            permitData.spender,
                            keccak256(abi.encodePacked(permitData.maxAmounts)),
                            permitData.nonce,
                            permitData.deadline,
                            permitData.witness
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

        if (permitData.sigType == SigType.ORDERED) {
            _useNonce(signer, permitData.nonce);
        } else if (permitData.sigType == SigType.UNORDERED) {
            _useUnorderedNonce(signer, permitData.nonce);
        }

        if (to.length == 1) {
            // send all tokens to the same recipient address if only one is specified
            // address recipient = to[0];
            for (uint256 i = 0; i < permitData.tokens.length; ++i) {
                ERC20(permitData.tokens[i]).transferFrom(signer, to[0], amounts[i]);
            }
        } else {
            for (uint256 i = 0; i < permitData.tokens.length; ++i) {
                ERC20(permitData.tokens[i]).transferFrom(signer, to[i], amounts[i]);
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
