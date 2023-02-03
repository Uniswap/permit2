// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {BaseAllowanceTransferTest} from "./BaseAllowanceTransferTest.t.sol";
import {Permit2ERC721} from "../src/ERC721/Permit2ERC721.sol";
import {TokenProviderERC721} from "./utils/TokenProviderERC721.sol";
import {PermitHashERC721} from "../src/ERC721/libraries/PermitHashERC721.sol";
import {PermitAbstraction} from "./utils/PermitAbstraction.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {IAllowanceTransferERC721} from "../src/ERC721/interfaces/IAllowanceTransferERC721.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract AllowanceTransferTestERC721 is TokenProviderERC721, BaseAllowanceTransferTest {
    uint256 currentId = 1;

    function setUp() public override {
        permit2 = address(new Permit2ERC721());
        DOMAIN_SEPARATOR = Permit2ERC721(permit2).DOMAIN_SEPARATOR();

        uint256 mintAmount = 10 ** 18;
        // amount for ERC20s
        defaultAmountOrId = 0;

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        // Use this address to gas test dirty writes later.
        fromPrivateKeyDirty = 0x56785678;
        fromDirty = vm.addr(fromPrivateKeyDirty);

        initializeTokens();

        setToken0(from);
        setTokenApprovals0(vm, from, address(permit2));

        setToken1(fromDirty);
        setTokenApprovals1(vm, fromDirty, address(permit2));

        // dirty the nonce for fromDirty address on token0 and token1
        // use token1 for fromDirty tests
        vm.startPrank(fromDirty);
        Permit2ERC721(permit2).invalidateNonces(token1(), address(this), 1);
        vm.stopPrank();
    }

    function getExpectedAmountOrSpender() public override returns (uint160) {
        // spender is this address
        return uint160(address(this));
    }

    function setAmountOrId(uint256 id) public override {
        currentId = id;
    }

    function getAmountOrId() public override returns (uint256) {
        // tokenId for token0 is 1
        return currentId;
    }

    function permit2Approve(address token, address spender, uint256 amountOrId, uint48 expiration) public override {
        Permit2ERC721(permit2).approve(token, spender, amountOrId, expiration);
    }

    function permit2Allowance(address from, address token, uint256 tokenIdOrSpender)
        public
        override
        returns (uint160, uint48, uint48)
    {
        (address spender1, uint48 expiration1, uint48 nonce1) =
            Permit2ERC721(address(permit2)).allowance(from, token, getAmountOrId());
        return (uint160(spender1), expiration1, nonce1);
    }

    function permit2Permit(address from, PermitAbstraction.IPermitSingle memory permit, bytes memory sig)
        public
        override
    {
        // convert IPermitSingle to AllowanceTransfer.PermitSingle
        IAllowanceTransferERC721.PermitSingle memory parsedPermit = IAllowanceTransferERC721.PermitSingle({
            details: IAllowanceTransferERC721.PermitDetails({
                token: permit.token,
                tokenId: permit.amountOrId,
                expiration: permit.expiration,
                nonce: permit.nonce
            }),
            spender: permit.spender,
            sigDeadline: permit.sigDeadline
        });

        Permit2ERC721(permit2).permit(from, parsedPermit, sig);
    }

    function permit2Permit(address from, PermitAbstraction.IPermitBatch memory permitBatch, bytes memory sig)
        public
        override
    {
        // convert IPermitBatch to IAllowanceTransferERC721.PermitBatch

        IAllowanceTransferERC721.PermitDetails[] memory details =
            new IAllowanceTransferERC721.PermitDetails[](permitBatch.tokens.length);
        for (uint256 i = 0; i < details.length; i++) {
            details[i] = IAllowanceTransferERC721.PermitDetails({
                token: permitBatch.tokens[i],
                tokenId: permitBatch.amountOrIds[i],
                expiration: permitBatch.expirations[i],
                nonce: permitBatch.nonces[i]
            });
        }
        IAllowanceTransferERC721.PermitBatch memory parsedPermitBatch = IAllowanceTransferERC721.PermitBatch({
            details: details,
            spender: permitBatch.spender,
            sigDeadline: permitBatch.sigDeadline
        });

        Permit2ERC721(permit2).permit(from, parsedPermitBatch, sig);
    }

    function permit2TransferFrom(address from, address to, uint160 amountOrId, address token) public override {
        Permit2ERC721(permit2).transferFrom(from, to, amountOrId, token);
    }

    function token0() public view override returns (address) {
        return address(_token0);
    }

    function token1() public view override returns (address) {
        return address(_token1);
    }

    function balanceOf(address token, address from) public override returns (uint256) {
        return MockERC20(token).balanceOf(from);
    }

    function getPermitSignature(IPermitSingle memory permit, uint256 privateKey, bytes32 domainSeparator)
        public
        override
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        return bytes.concat(r, s, bytes1(v));
    }

    function getCompactPermitSignature(IPermitSingle memory permit, uint256 privateKey, bytes32 domainSeparator)
        public
        override
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        bytes32 vs;
        (r, vs) = getCompactSignature(v, r, s);
        return bytes.concat(r, vs);
    }

    function getPermitSignatureRaw(IPermitSingle memory permit, uint256 privateKey, bytes32 domainSeparator)
        internal
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        // convert IPermitSingle to permit details & hash
        bytes32 permitHash = keccak256(
            abi.encode(
                PermitHashERC721._PERMIT_DETAILS_TYPEHASH,
                permit.token,
                permit.amountOrId,
                permit.expiration,
                permit.nonce
            )
        );

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(PermitHashERC721._PERMIT_SINGLE_TYPEHASH, permitHash, permit.spender, permit.sigDeadline)
                )
            )
        );

        (v, r, s) = vm.sign(privateKey, msgHash);
    }

    function getPermitBatchSignature(IPermitBatch memory permit, uint256 privateKey, bytes32 domainSeparator)
        public
        override
        returns (bytes memory)
    {
        bytes32[] memory permitHashes = new bytes32[](permit.tokens.length);
        for (uint256 i = 0; i < permit.tokens.length; ++i) {
            permitHashes[i] = keccak256(
                abi.encode(
                    PermitHashERC721._PERMIT_DETAILS_TYPEHASH,
                    permit.tokens[i],
                    permit.amountOrIds[i],
                    permit.expirations[i],
                    permit.nonces[i]
                )
            );
        }

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        PermitHashERC721._PERMIT_BATCH_TYPEHASH,
                        keccak256(abi.encodePacked(permitHashes)),
                        permit.spender,
                        permit.sigDeadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }
}
