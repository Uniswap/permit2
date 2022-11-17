// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SignatureVerification} from "../../src/libraries/SignatureVerification.sol";

contract MockSignatureVerification {
    function verify(bytes calldata sig, bytes32 hashed, address signer) public view {
        SignatureVerification.verify(sig, hashed, signer);
    }
}
