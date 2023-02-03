// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {BaseAllowanceTransferTest} from "./BaseAllowanceTransferTest.t.sol";
import {Permit2} from "../src/ERC20/Permit2.sol";
import {TokenProviderERC20} from "./utils/TokenProviderERC20.sol";
import {PermitHash} from "../src/ERC20/libraries/PermitHash.sol";
import {PermitAbstraction} from "./utils/PermitAbstraction.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {IAllowanceTransfer} from "../src/ERC20/interfaces/IAllowanceTransfer.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract AllowanceTransferTestERC20 is TokenProviderERC20, BaseAllowanceTransferTest {
    function setUp() public override {
        permit2 = address(new Permit2());
        DOMAIN_SEPARATOR = Permit2(permit2).DOMAIN_SEPARATOR();

        // amount for ERC20s
        defaultAmountOrId = 10 ** 18;

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        // Use this address to gas test dirty writes later.
        fromPrivateKeyDirty = 0x56785678;
        fromDirty = vm.addr(fromPrivateKeyDirty);

        initializeTokens();

        setTokens(from);
        setTokenApprovals(vm, from, address(permit2));

        setTokens(fromDirty);
        setTokenApprovals(vm, fromDirty, address(permit2));

        // dirty the nonce for fromDirty address on token0 and token1
        vm.startPrank(fromDirty);
        Permit2(permit2).invalidateNonces(token0(), address(this), 1);
        Permit2(permit2).invalidateNonces(token1(), address(this), 1);
        vm.stopPrank();
        // ensure address3 has some balance of token0 and token1 for dirty sstore on transfer
        MockERC20(token0()).mint(address3, defaultAmountOrId);
        MockERC20(token1()).mint(address3, defaultAmountOrId);
    }

    function getAmountOrId() public override returns (uint256) {
        // default amount
        return defaultAmountOrId;
    }

    function getExpectedAmountOrSpender() public override returns (uint160) {
        // expected amount is the defaultAmountOrId
        return uint160(defaultAmountOrId);
    }

    function permit2Approve(address token, address spender, uint256 amountOrId, uint48 expiration) public override {
        Permit2(permit2).approve(token, spender, uint160(amountOrId), expiration);
    }

    function permit2Allowance(address from, address token, uint256 tokenIdOrSpender)
        public
        override
        returns (uint160, uint48, uint48)
    {
        return Permit2(permit2).allowance(from, token, address(uint160(tokenIdOrSpender)));
    }

    function permit2Permit(address from, PermitAbstraction.IPermitSingle memory permit, bytes memory sig)
        public
        override
    {
        // convert IPermitSingle to AllowanceTransfer.PermitSingle
        IAllowanceTransfer.PermitSingle memory parsedPermit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: permit.token,
                amount: permit.amountOrId,
                expiration: permit.expiration,
                nonce: permit.nonce
            }),
            spender: permit.spender,
            sigDeadline: permit.sigDeadline
        });

        Permit2(permit2).permit(from, parsedPermit, sig);
    }

    function permit2Permit(address from, PermitAbstraction.IPermitBatch memory permitBatch, bytes memory sig)
        public
        override
    {
        // convert IPermitBatch to IAllowanceTransfer.PermitBatch

        IAllowanceTransfer.PermitDetails[] memory details =
            new IAllowanceTransfer.PermitDetails[](permitBatch.tokens.length);
        for (uint256 i = 0; i < details.length; i++) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: permitBatch.tokens[i],
                amount: permitBatch.amountOrIds[i],
                expiration: permitBatch.expirations[i],
                nonce: permitBatch.nonces[i]
            });
        }
        IAllowanceTransfer.PermitBatch memory parsedPermitBatch = IAllowanceTransfer.PermitBatch({
            details: details,
            spender: permitBatch.spender,
            sigDeadline: permitBatch.sigDeadline
        });

        Permit2(permit2).permit(from, parsedPermitBatch, sig);
    }

    function permit2TransferFrom(address from, address to, uint160 amountOrId, address token) public override {
        Permit2(permit2).transferFrom(from, to, amountOrId, token);
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
                PermitHash._PERMIT_DETAILS_TYPEHASH, permit.token, permit.amountOrId, permit.expiration, permit.nonce
            )
        );

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(PermitHash._PERMIT_SINGLE_TYPEHASH, permitHash, permit.spender, permit.sigDeadline)
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
                    PermitHash._PERMIT_DETAILS_TYPEHASH,
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
                        PermitHash._PERMIT_BATCH_TYPEHASH,
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
