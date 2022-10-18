// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Permit, Signature, PermitBatch, SigType, InvalidSignature, DeadlinePassed, LengthMismatch} from "./Permit2Utils.sol";
import {Nonces} from "./base/Nonces.sol";
import {DomainSeparator} from "./base/DomainSeparator.sol";

abstract contract SignatureTransfer is Nonces, DomainSeparator {
    error NotSpender();
    error InvalidAmount();

    /// @dev sigType field distinguishes between using unordered nonces or ordered nonces for replay protection
    bytes32 public constant _PERMIT_TRANSFER_TYPEHASH = keccak256(
        "PermitTransferFrom(uint8 sigType,address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(uint8 sigType,address[] tokens,address spender,uint256[] maxAmounts,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    /// @notice Transfers a token using a signed permit message.
    /// @dev If to is the zero address, the tokens are sent to the spender.
    /// Can use ordered or unordered nonces for replay protection.
    function permitTransferFrom(Permit calldata permitData, address to, uint256 amount, Signature calldata sig)
        public
        returns (address signer)
    {
        _validatePermit(permitData.spender, permitData.deadline, permitData.maxAmount, amount);

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
        _validateBatchPermit(permitData, to, amounts);

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
            unchecked {
                for (uint256 i = 0; i < permitData.tokens.length; ++i) {
                    ERC20(permitData.tokens[i]).transferFrom(signer, to[0], amounts[i]);
                }
            }
        } else {
            unchecked {
                for (uint256 i = 0; i < permitData.tokens.length; ++i) {
                    ERC20(permitData.tokens[i]).transferFrom(signer, to[i], amounts[i]);
                }
            }
        }
    }

    function _validateBatchPermit(PermitBatch memory permitData, address[] memory to, uint256[] memory amounts)
        internal
        view
    {
        bool validMultiAddr = to.length == permitData.tokens.length && amounts.length == permitData.tokens.length;
        bool validSingleAddr = to.length == 1 && amounts.length == permitData.tokens.length;

        if (!(validMultiAddr || validSingleAddr)) {
            revert LengthMismatch();
        }

        if (msg.sender != permitData.spender) {
            revert NotSpender();
        }
        if (block.timestamp > permitData.deadline) {
            revert DeadlinePassed();
        }

        unchecked {
            for (uint256 i = 0; i < amounts.length; ++i) {
                if (amounts[i] > permitData.maxAmounts[i]) {
                    revert InvalidAmount();
                }
            }
        }
    }

    function _validatePermit(address spender, uint256 deadline, uint256 maxAmount, uint256 amount) internal view {
        if (msg.sender != spender) {
            revert NotSpender();
        }
        if (block.timestamp > deadline) {
            revert DeadlinePassed();
        }
        if (amount > maxAmount) {
            revert InvalidAmount();
        }
    }
}
