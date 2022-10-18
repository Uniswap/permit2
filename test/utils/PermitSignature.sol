// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Vm} from "forge-std/Vm.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/draft-EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Signature, Permit} from "../../src/Permit2Utils.sol";
import {Permit2} from "../../src/Permit2.sol";
import {AllowanceMath} from "../../src/libraries/AllowanceMath.sol";

contract PermitSignature {
    bytes32 public constant _PERMIT_TRANSFER_TYPEHASH = keccak256(
        "PermitTransferFrom(uint8 sigType,address token,address spender,uint256 maxAmount,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    bytes32 public constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address token,address spender,uint160 amount,uint64 expiration,uint32 nonce,uint256 sigDeadline,bytes32 witness)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(uint8 sigType,address[] tokens,address spender,uint256[] maxAmounts,uint256 nonce,uint256 deadline,bytes32 witness)"
    );

    function getPermitSignature(Vm vm, Permit memory permit, uint32 nonce, uint256 privateKey, bytes32 domainSeparator)
        internal
        returns (Signature memory sig)
    {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_TYPEHASH,
                        permit.token,
                        permit.spender,
                        permit.amount,
                        permit.expiration,
                        nonce,
                        permit.sigDeadline,
                        permit.witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        sig = Signature(v, r, s);
    }

    function defaultERC20PermitAllowance(address token0, uint160 amount, uint64 expiration)
        internal
        view
        returns (Permit memory)
    {
        return Permit({
            token: token0,
            spender: address(this),
            amount: amount,
            expiration: expiration,
            sigDeadline: block.timestamp + 100,
            witness: 0x0
        });
    }
}
