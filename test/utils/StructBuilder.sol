// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";

library StructBuilder {
    function fill(uint256 length, address token, uint160 amount, address to)
        external
        pure
        returns (IAllowanceTransfer.TransferDetails[] memory tokenDetails)
    {
        tokenDetails = new IAllowanceTransfer.TransferDetails[](length);
        for (uint256 i = 0; i < length; ++i) {
            tokenDetails[i] = IAllowanceTransfer.TransferDetails({token: token, amount: amount, to: to});
        }
    }
}
