// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC1271} from "../interfaces/IERC1271.sol";

library SignatureRecovery {
    error InvalidSignature();
    error InvalidContractSignature();

    function recover(bytes calldata signature, bytes32 hash, address claimedSigner) internal view returns (address) {
        if (claimedSigner.code.length == 0) {
            bytes32 r = bytes32(signature[0:32]);
            bytes32 s = bytes32(signature[32:64]);
            uint8 v = uint8(signature[64]);
            address signer = ecrecover(hash, v, r, s);
            if (signer == address(0)) {
                revert InvalidSignature();
            }
            return signer;
        } else {
            bytes4 magicValue = IERC1271(claimedSigner).isValidSignature(hash, signature);
            if (magicValue != IERC1271.isValidSignature.selector) {
                revert InvalidContractSignature();
            }
            return claimedSigner;
        }
    }
}
