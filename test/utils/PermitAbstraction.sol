// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from "../../src/ERC20/interfaces/IAllowanceTransfer.sol";
import {AmountBuilder} from "./AmountBuilder.sol";

// Structs are used for type abstraction in the tests and later converted to the respective permit2 structs
contract PermitAbstraction {
    struct IPermitSingle {
        address token;
        uint160 amountOrId;
        uint48 expiration;
        uint48 nonce;
        address spender;
        uint256 sigDeadline;
    }

    struct IPermitBatch {
        address[] tokens;
        uint160[] amountOrIds;
        uint48[] expirations;
        uint48[] nonces;
        address spender;
        uint256 sigDeadline;
    }

    function defaultPermitAllowance(address token, uint160 amountOrId, uint48 expiration, uint48 nonce)
        public
        view
        returns (IPermitSingle memory)
    {
        IAllowanceTransfer.PermitDetails memory details =
            IAllowanceTransfer.PermitDetails({token: token, amount: amountOrId, expiration: expiration, nonce: nonce});
        return IPermitSingle({
            token: token,
            amountOrId: amountOrId,
            expiration: expiration,
            nonce: nonce,
            spender: address(this),
            sigDeadline: block.timestamp + 100
        });
    }

    function defaultPermitBatchAllowance(address[] memory tokens, uint160 amountOrId, uint48 expiration, uint48 nonce)
        public
        view
        returns (IPermitBatch memory)
    {
        uint160[] memory amountOrIds = AmountBuilder.fillUInt160(tokens.length, amountOrId);
        uint48[] memory expirations = AmountBuilder.fillUInt48(tokens.length, expiration);
        uint48[] memory nonces = AmountBuilder.fillUInt48(tokens.length, nonce);
        return IPermitBatch({
            tokens: tokens,
            amountOrIds: amountOrIds,
            expirations: expirations,
            nonces: nonces,
            spender: address(this),
            sigDeadline: block.timestamp + 100
        });
    }
}
