// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../../src/interfaces/ISignatureTransfer.sol";
import {AddressBuilder} from "./AddressBuilder.sol";

library StructBuilder {
    function fillTransferDetail(uint256 length, address token, uint160 amount, address to)
        external
        pure
        returns (IAllowanceTransfer.TransferDetail[] memory tokenDetails)
    {
        tokenDetails = new IAllowanceTransfer.TransferDetail[](length);
        for (uint256 i = 0; i < length; ++i) {
            tokenDetails[i] = IAllowanceTransfer.TransferDetail({token: token, amount: amount, to: to});
        }
    }

    function fillToAmountPair(uint256 length, uint256 amount, address to)
        external
        pure
        returns (ISignatureTransfer.ToAmountPair[] memory toAmountPairs)
    {
        return fillToAmountPairDifferentAddresses(amount, AddressBuilder.fill(length, to));
    }

    function fillToAmountPairDifferentAddresses(uint256 amount, address[] memory tos)
        public
        pure
        returns (ISignatureTransfer.ToAmountPair[] memory toAmountPairs)
    {
        toAmountPairs = new ISignatureTransfer.ToAmountPair[](tos.length);
        for (uint256 i = 0; i < tos.length; ++i) {
            toAmountPairs[i] = ISignatureTransfer.ToAmountPair({to: tos[i], requestedAmount: amount});
        }
    }
}
