// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Signature} from "../Permit2Utils.sol";
import {IERC1271} from "../interfaces/IERC1271.sol";

library SignatureRecovery {
    error InvalidSignature();
    error NotAContract();
    error InvalidContractSignature();

    function recover(Signature calldata sig, bytes32 hash) internal pure returns (address signer) {
        signer = ecrecover(hash, sig.v, sig.r, sig.s);
        if (signer == address(0)) {
            revert InvalidSignature();
        }
    }

    function recover(bytes calldata signature, address claimedSigner, bytes32 hash) internal view {
        if (claimedSigner.code.length == 0) {
            revert NotAContract();
        }
        bytes4 magicValue = IERC1271(claimedSigner).isValidSignature(hash, signature);
        if (magicValue != IERC1271.isValidSignature.selector) {
            revert InvalidContractSignature();
        }
    }
}
