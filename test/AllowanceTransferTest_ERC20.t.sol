// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {BaseAllowanceTransferTest} from "./BaseAllowanceTransferTest.t.sol";
import {Permit2} from "../src/ERC20/Permit2.sol";
import {TokenProvider_ERC20} from "./utils/TokenProvider_ERC20.sol";
import {PermitHash} from "../src/ERC20/libraries/PermitHash.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {IAllowanceTransfer} from "../src/ERC20/interfaces/IAllowanceTransfer.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract AllowanceTransferTest_ERC20 is TokenProvider_ERC20, BaseAllowanceTransferTest {
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

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(permit2));

        setERC20TestTokens(fromDirty);
        setERC20TestTokenApprovals(vm, fromDirty, address(permit2));

        // dirty the nonce for fromDirty address on token0 and token1
        vm.startPrank(fromDirty);
        Permit2(permit2).invalidateNonces(token0(), address(this), 1);
        Permit2(permit2).invalidateNonces(token1(), address(this), 1);
        vm.stopPrank();
        // ensure address3 has some balance of token0 and token1 for dirty sstore on transfer
        MockERC20(token0()).mint(address3, defaultAmountOrId);
        MockERC20(token1()).mint(address3, defaultAmountOrId);
    }

    function permit2Approve(address token, address spender, uint160 amountOrId, uint48 expiration) public override {
        Permit2(permit2).approve(token, spender, amountOrId, expiration);
    }

    function permit2Allowance(address from, address token, address spender)
        public
        override
        returns (uint160, uint48, uint48)
    {
        return Permit2(permit2).allowance(from, token, spender);
    }

    function permit2Permit(address from, PermitSignature.IPermitSingle memory permit, bytes memory sig)
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

    function token0() public view override returns (address) {
        return address(_token0);
    }

    function token1() public view override returns (address) {
        return address(_token1);
    }

    function getPermitSignature(IPermitSingle memory permit, uint256 privateKey, bytes32 domainSeparator)
        public
        override
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        return bytes.concat(r, s, bytes1(v));
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
}
