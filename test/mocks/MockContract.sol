// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../src/interfaces/IPermit2.sol";

contract MockContract {
    IPermit2 public immutable permit2;

    constructor(IPermit2 _permit2) {
        permit2 = _permit2;
    }

    function depositWithPermit(
        address token,
        uint256 amount,
        ISignatureTransfer.PermitTransferFrom calldata permitData,
        bytes calldata sig
    ) external {
        require(token == permitData.permitted.token, "MockContract: token mismatch");
        permit2.permitTransferFrom(
            permitData, ISignatureTransfer.SignatureTransferDetails(address(this), amount), msg.sender, sig
        );
    }
}
