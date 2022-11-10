// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../../src/interfaces/ISignatureTransfer.sol";
import {AddressBuilder} from "./AddressBuilder.sol";

library StructBuilder {
    function fillAllowanceTransferDetail(
        uint256 length,
        address[] memory tokens,
        uint160 amount,
        address to,
        address[] memory owners
    ) external pure returns (IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails) {
        transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](length);
        for (uint256 i = 0; i < length; ++i) {
            transferDetails[i] =
                IAllowanceTransfer.AllowanceTransferDetails({from: owners[i], token: tokens[i], amount: amount, to: to});
        }
    }

    function fillAllowanceTransferDetail(
        uint256 length,
        address token,
        uint160 amount,
        address to,
        address[] memory owners
    ) external pure returns (IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails) {
        transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](length);
        for (uint256 i = 0; i < length; ++i) {
            transferDetails[i] =
                IAllowanceTransfer.AllowanceTransferDetails({from: owners[i], token: token, amount: amount, to: to});
        }
    }

    function fillSigTransferDetails(uint256 length, uint256 amount, address to)
        external
        pure
        returns (ISignatureTransfer.SignatureTransferDetails[] memory transferDetails)
    {
        return fillSigTransferDetails(amount, AddressBuilder.fill(length, to));
    }

    function fillSigTransferDetails(uint256 amount, address[] memory tos)
        public
        pure
        returns (ISignatureTransfer.SignatureTransferDetails[] memory transferDetails)
    {
        transferDetails = new ISignatureTransfer.SignatureTransferDetails[](tos.length);
        for (uint256 i = 0; i < tos.length; ++i) {
            transferDetails[i] = ISignatureTransfer.SignatureTransferDetails({to: tos[i], requestedAmount: amount});
        }
    }
}
