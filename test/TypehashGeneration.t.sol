// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {PermitHash} from "../src/libraries/PermitHash.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {MockSignatureVerification} from "./mocks/MockSignatureVerification.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";

contract TypehashGeneration is Test, PermitSignature, TokenProvider {
    using PermitHash for *;

    MockPermit2 permit2;

    uint256 PRIV_KEY_TEST = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address from = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address verifyingContract;

    address token;
    address spender;
    uint160 amount;
    uint48 expiration;
    uint256 sigDeadline;
    uint48 nonce;

    bytes32 DOMAIN_SEPARATOR;

    MockSignatureVerification mockSig;

    function setUp() public {
        permit2 = new MockPermit2();

        verifyingContract = address(permit2);
        console2.log(verifyingContract);

        token = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        spender = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        amount = 100;
        expiration = 946902158100;
        sigDeadline = 146902158100;
        nonce = 0;

        console2.log(amount);

        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        mockSig = new MockSignatureVerification();
    }

    function testPermitSingle() public {
        // metamask wallet signed data
        // 0xdb5507adaba8ed8e1d83dc7cb64980735c4769076c657d80563ce9a991fbb1981d07973917923c7942307e63285ff2e9e8d435fc4da8cdc7546a669bf474fb6d1b
        bytes32 r = 0xdb5507adaba8ed8e1d83dc7cb64980735c4769076c657d80563ce9a991fbb198;
        bytes32 s = 0x1d07973917923c7942307e63285ff2e9e8d435fc4da8cdc7546a669bf474fb6d;
        uint8 v = 0x1b;

        console2.logBytes32(r);
        console2.logBytes32(s);
        console2.log(v);

        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // generate local data
        IAllowanceTransfer.PermitDetails memory details =
            IAllowanceTransfer.PermitDetails({token: token, amount: amount, expiration: expiration, nonce: nonce});

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({details: details, spender: spender, sigDeadline: sigDeadline});

        // generate hash of local data
        bytes32 hashedPermit = permit.hash();

        // extra check: generate sig of local data and check that it equals the metamask sig
        (uint8 v1, bytes32 r1, bytes32 s1) = getPermitSignatureRaw(permit, PRIV_KEY_TEST, DOMAIN_SEPARATOR);
        assertEq(v, v1);
        assertEq(r, r1);
        assertEq(s, s1);

        // verify the signed data againt the locally generated hash
        // this should not revert, validating that from is indeed the signer
        mockSig.verify(sig, hashedPermit, from);
    }
}
