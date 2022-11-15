// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {PermitHash} from "../src/libraries/PermitHash.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {MockSignatureVerification} from "./mocks/MockSignatureVerification.sol";
import {MockHash} from "./mocks/MockHash.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";

contract TypehashGeneration is Test, PermitSignature {
    using PermitHash for *;
    using AddressBuilder for address[];

    MockHash mockHash;

    uint256 PRIV_KEY_TEST = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address from = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address verifyingContract;
    uint256 chainId;

    address token1;
    address token2;
    address spender;
    uint160 amount;
    uint48 expiration;
    uint256 sigDeadline;
    uint48 nonce;

    bytes32 DOMAIN_SEPARATOR;

    MockSignatureVerification mockSig;

    function setUp() public {
        mockHash = new MockHash();
        // hardcoding these to match mm inputs
        verifyingContract = 0xCe71065D4017F316EC606Fe4422e11eB2c47c246;
        chainId = 1;
        token1 = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        token2 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        spender = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        amount = 100;
        expiration = 946902158100;
        sigDeadline = 146902158100;
        nonce = 0;

        DOMAIN_SEPARATOR = _buildDomainSeparator();

        mockSig = new MockSignatureVerification();
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        bytes32 nameHash = keccak256("Permit2");
        bytes32 typeHash = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
        return keccak256(abi.encode(typeHash, nameHash, chainId, verifyingContract));
    }

    function testPermitSingle() public {
        // metamask wallet signed data
        // 0xdb5507adaba8ed8e1d83dc7cb64980735c4769076c657d80563ce9a991fbb1981d07973917923c7942307e63285ff2e9e8d435fc4da8cdc7546a669bf474fb6d1b
        bytes32 r = 0xdb5507adaba8ed8e1d83dc7cb64980735c4769076c657d80563ce9a991fbb198;
        bytes32 s = 0x1d07973917923c7942307e63285ff2e9e8d435fc4da8cdc7546a669bf474fb6d;
        uint8 v = 0x1b;

        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // generate local data
        IAllowanceTransfer.PermitDetails memory details =
            IAllowanceTransfer.PermitDetails({token: token1, amount: amount, expiration: expiration, nonce: nonce});

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({details: details, spender: spender, sigDeadline: sigDeadline});

        bytes memory localSig = getPermitSignature(permit, PRIV_KEY_TEST, DOMAIN_SEPARATOR);
        // generate hash of local data
        bytes32 hashedPermit = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, permit.hash()));

        // verify the signed data againt the locally generated hash
        // this should not revert, validating that from is indeed the signer
        mockSig.verify(sig, hashedPermit, from);
        // also verify typehash with local sig
        mockSig.verify(localSig, hashedPermit, from);
    }

    function testPermitBatch() public {
        // metamask wallet signed data
        // 0x3d298c897075538134ee0003bba9b149fac6e4b3496e34272f6731c32be2a710682657710eb4208db1eb6a6dac08b375f171733604e4e1deed30d49e22d0c42f1c
        bytes32 r = 0x3d298c897075538134ee0003bba9b149fac6e4b3496e34272f6731c32be2a710;
        bytes32 s = 0x682657710eb4208db1eb6a6dac08b375f171733604e4e1deed30d49e22d0c42f;
        uint8 v = 0x1c;

        bytes memory sig = bytes.concat(r, s, bytes1(v));

        // generate local data
        address[] memory tokens = AddressBuilder.fill(1, token1).push(token2);
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens[i],
                amount: amount,
                expiration: expiration,
                nonce: nonce
            });
        }

        IAllowanceTransfer.PermitBatch memory permit =
            IAllowanceTransfer.PermitBatch({details: details, spender: spender, sigDeadline: sigDeadline});

        bytes memory localSig = getPermitBatchSignature(permit, PRIV_KEY_TEST, DOMAIN_SEPARATOR);
        // generate hash of local data
        bytes32 hashedPermit = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, permit.hash()));

        // verify the signed data againt the locally generated hash
        // this should not revert, validating that from is indeed the signer
        mockSig.verify(sig, hashedPermit, from);
        // also verify typehash with local sig
        mockSig.verify(localSig, hashedPermit, from);
    }

    function testPermitTransferFrom() public view {
        // metamask wallet signed data
        // 0x3d298c897075538134ee0003bba9b149fac6e4b3496e34272f6731c32be2a710682657710eb4208db1eb6a6dac08b375f171733604e4e1deed30d49e22d0c42f1c
        bytes32 r = 0xc12d33a96aef9ea42f1ad72587f52b5113b68d7b8fe35675fc0bb1ade3773455;
        bytes32 s = 0x56f3bbecb0c791bc9e23e58ce3a889f39c4b37b315faa264b8e4b5f2d5f7b365;
        uint8 v = 0x1b;

        bytes memory sig = bytes.concat(r, s, bytes1(v));

        ISignatureTransfer.PermitTransferFrom memory permitTransferFrom = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: token1, amount: amount}),
            nonce: nonce,
            deadline: sigDeadline
        });

        // skip local sig since address(this) is used on reconstruction

        bytes32 hashedPermit =
            keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, mockHash.hash(permitTransferFrom)));

        // verify the signed data againt the locally generated hash
        // this should not revert, validating that from is indeed the signer
        mockSig.verify(sig, hashedPermit, from);
    }

    function testPermitBatchTransferFrom() public view {
        // metamask wallet signed data
        // 0x8987ef38bdbf7f7dd8f133c92a331b5359036ca9732b2cf15750f1a56050159e10a62544d74648d917ce4c1b670024a771aadb8bace7db63ef6f5d3975451b231b
        bytes32 r = 0x8987ef38bdbf7f7dd8f133c92a331b5359036ca9732b2cf15750f1a56050159e;
        bytes32 s = 0x10a62544d74648d917ce4c1b670024a771aadb8bace7db63ef6f5d3975451b23;
        uint8 v = 0x1b;

        bytes memory sig = bytes.concat(r, s, bytes1(v));

        address[] memory tokens = AddressBuilder.fill(1, token1).push(token2);

        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            permitted[i] = ISignatureTransfer.TokenPermissions({token: tokens[i], amount: amount});
        }
        ISignatureTransfer.PermitBatchTransferFrom memory permitBatchTransferFrom =
            ISignatureTransfer.PermitBatchTransferFrom({permitted: permitted, nonce: nonce, deadline: sigDeadline});

        // skip local sig since address(this) is used on reconstruction

        bytes32 hashedPermit =
            keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, mockHash.hash(permitBatchTransferFrom)));

        // verify the signed data againt the locally generated hash
        // this should not revert, validating that from is indeed the signer
        mockSig.verify(sig, hashedPermit, from);
    }
}
