// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureRecovery} from "./libraries/SignatureRecovery.sol";
import {PermitTransfer, Signature, PermitBatch, SigType, InvalidNonce} from "./Permit2Utils.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {DomainSeparator} from "./DomainSeparator.sol";

contract SignatureTransfer is DomainSeparator {
    using SignatureRecovery for Signature;

    error NotSpender();
    error DeadlinePassed();
    error InvalidAmount();
    error LengthMismatch();

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
    function permitTransferFrom(PermitTransfer calldata permit, address to, uint256 amount, Signature calldata sig)
        public
        returns (address signer)
    {
        _validatePermit(permit.spender, permit.deadline, permit.maxAmount, amount);

        signer = sig.recover(
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
            )
        );

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

        signer = sig.recover(
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
            )
        );

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

    mapping(address => uint256) public nonces;
    mapping(address => mapping(uint248 => uint256)) public nonceBitmap;

    /// @notice Checks whether a nonce is taken. Then sets an increasing nonce on the from address.
    function _useNonce(address from, uint256 nonce) internal {
        if (nonce != nonces[from]) {
            revert InvalidNonce();
        }
        unchecked {
            nonces[from] = nonce + 1;
        }
    }

    /// @notice Checks whether a nonce is taken. Then sets the bit at the bitPos in the bitmap at the wordPos.
    function _useUnorderedNonce(address from, uint256 nonce) internal {
        (uint248 wordPos, uint8 bitPos) = bitmapPositions(nonce);
        uint256 bitmap = nonceBitmap[from][wordPos];
        if ((bitmap >> bitPos) & 1 == 1) {
            revert InvalidNonce();
        }
        nonceBitmap[from][wordPos] = bitmap | (1 << bitPos);
    }

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces.
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap.
    /// The last 8 bits of the nonce value is the position of the bit in the bitmap.
    function bitmapPositions(uint256 nonce) public pure returns (uint248 wordPos, uint8 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce & 255);
    }

    /// @notice Invalidates the bits specified in `mask` for the bitmap at `wordPos`.
    function invalidateUnorderedNonces(uint248 wordPos, uint256 mask) public {
        nonceBitmap[msg.sender][wordPos] |= mask;
    }
}
