// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Permit, Signature, PermitBatch, SigType} from "./Permit2.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "forge-std/console2.sol";

abstract contract SignatureTransfer {
    error NotSpender();
    error DeadlinePassed();
    error InvalidAmount();
    error InvalidSignature();
    error LengthMismatch();

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
        _validatePermit(permit.spender, permit.deadline, permit.maxAmount, amount);

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
        _validateBatchPermit(permit, to, amounts);

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
            unchecked {
                for (uint256 i = 0; i < permit.tokens.length; ++i) {
                    ERC20(permit.tokens[i]).transferFrom(signer, to[0], amounts[i]);
                }
            }
        } else {
            unchecked {
                for (uint256 i = 0; i < permit.tokens.length; ++i) {
                    ERC20(permit.tokens[i]).transferFrom(signer, to[i], amounts[i]);
                }
            }
        }
    }

    function _validateBatchPermit(PermitBatch memory permit, address[] memory to, uint256[] memory amounts)
        internal
        view
    {
        bool validMultiAddr = to.length == permit.tokens.length && amounts.length == permit.tokens.length;
        bool validSingleAddr = to.length == 1 && amounts.length == permit.tokens.length;

        if (!(validMultiAddr || validSingleAddr)) {
            revert LengthMismatch();
        }

        if (msg.sender != permit.spender) {
            revert NotSpender();
        }
        if (block.timestamp > permit.deadline) {
            revert DeadlinePassed();
        }

        unchecked {
            for (uint256 i = 0; i < amounts.length; ++i) {
                if (amounts[i] > permit.maxAmounts[i]) {
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
