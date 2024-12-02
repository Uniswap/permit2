// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {IAllowanceTransfer} from "./interfaces/IAllowanceTransfer.sol";
import {IFlashAllowanceTransfer} from "./interfaces/IFlashAllowanceTransfer.sol";

contract FlashAllowanceTransfer is IFlashAllowanceTransfer {
    using SafeTransferLib for ERC20;

    bytes32 private constant _TEMPORARY_ALLOWANCES_SLOT = bytes32(uint256(keccak256("Allowance.allowance")) - 1);

    /// @notice Maps users to tokens to spender addresses and information about the approval on the token
    /// @dev Indexed in the order of token owner address, token address, spender address
    /// @dev The stored word saves the allowed amount. Defined and commented, but used equivalent in inline assembly.
    //mapping(address => mapping(address => mapping(address => uint256))) private allowance;

    /// @inheritdoc IFlashAllowanceTransfer
    /// @dev Does not emit event as approval is reset at the end of txn, and an event is emitted by the transferFrom call
    function flashApprove(address token, address spender, uint256 amount) external {
        _setTemporaryAllowance(msg.sender, token, spender, amount);
    }

    /// @inheritdoc IFlashAllowanceTransfer
    function flashTransferFrom(address from, address to, uint256 amount, address token) external {
        _flashTransfer(from, to, amount, token);
    }

    /// @inheritdoc IFlashAllowanceTransfer
    function flashTransferFrom(IAllowanceTransfer.AllowanceTransferDetails[] calldata transferDetails) external {
        unchecked {
            uint256 length = transferDetails.length;
            for (uint256 i = 0; i < length; ++i) {
                IAllowanceTransfer.AllowanceTransferDetails memory transferDetail = transferDetails[i];
                _flashTransfer(transferDetail.from, transferDetail.to, uint256(transferDetail.amount), transferDetail.token);
            }
        }
    }

    /// @notice Internal function for transferring tokens using transient allowances
    function _flashTransfer(address from, address to, uint256 amount, address token) private {
        uint256 allowedAmount = _getTemporaryAllowance(from, token, msg.sender);

        if (allowedAmount != type(uint256).max) {
            if (amount > allowedAmount) {
                revert IAllowanceTransfer.InsufficientAllowance(allowedAmount);
            } else {
                unchecked {
                    allowedAmount -= amount;
                }
            }
        }

        // Transfer the tokens from the from address to the recipient.
        ERC20(token).safeTransferFrom(from, to, amount);
    }

    function _setTemporaryAllowance(address owner, address token, address spender, uint256 value) internal {
        bytes32 slot = _allowanceSlot(owner, token, spender);
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    function _getTemporaryAllowance(address owner, address token, address spender) internal view returns (uint256 allowed) {
        bytes32 slot = _allowanceSlot(owner, token, spender);
        assembly ("memory-safe") {
            allowed := tload(slot)
        }
    }

    /// @notice Returns the position key for the allowance
    /// @dev equivalent to mapping(address => mapping(address => mapping(address => uint256)))
    function _allowanceSlot(address owner, address spender, address token) private pure returns (bytes32) {
        return keccak256(abi.encode(spender, keccak256(abi.encode(token, keccak256(abi.encode(owner, _TEMPORARY_ALLOWANCES_SLOT))))));
    }
}
