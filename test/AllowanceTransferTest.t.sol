// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {SignatureVerification} from "../src/libraries/SignatureVerification.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {StructBuilder} from "./utils/StructBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {AllowanceTransfer} from "../src/AllowanceTransfer.sol";
import {SignatureExpired, InvalidNonce} from "../src/PermitErrors.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

contract AllowanceTransferTest is Test, TokenProvider, PermitSignature, GasSnapshot {
    using AddressBuilder for address[];
    using stdStorage for StdStorage;

    event NonceInvalidation(
        address indexed owner, address indexed token, address indexed spender, uint32 newNonce, uint32 oldNonce
    );
    event Approval(address indexed owner, address indexed token, address indexed spender, uint160 amount);
    event Lockdown(address indexed owner, address token, address spender);

    MockPermit2 permit2;

    address from;
    uint256 fromPrivateKey;

    address fromDirty;
    uint256 fromPrivateKeyDirty;

    address address0 = address(0);
    address address2 = address(2);

    uint160 defaultAmount = 10 ** 18;
    uint32 defaultNonce = 0;
    uint32 dirtyNonce = 1;
    uint64 defaultExpiration = uint64(block.timestamp + 5);

    // has some balance of token0
    address address3 = address(3);

    bytes32 DOMAIN_SEPARATOR;

    function setUp() public {
        permit2 = new MockPermit2();
        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

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
        permit2.setAllowance(fromDirty, address(token0), address(this), 1);
        permit2.setAllowance(fromDirty, address(token1), address(this), 1);

        // ensure address3 has some balance of token0 and token1 for dirty sstore on transfer
        token0.mint(address3, defaultAmount);
        token1.mint(address3, defaultAmount);
    }

    function testApprove() public {
        vm.prank(from);
        vm.expectEmit(true, true, true, true);
        emit Approval(from, address(token0), address(this), defaultAmount);
        permit2.approve(address(token0), address(this), defaultAmount, defaultExpiration);

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 0);
    }

    function testSetAllowance() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        snapStart("permitCleanWrite");
        permit2.permit(from, permit, sig);
        snapEnd();

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
    }

    function testSetAllowanceDirtyWrite() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        snapStart("permitDirtyWrite");
        permit2.permit(fromDirty, permit, sig);
        snapEnd();

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 2);
    }

    function testSetAllowanceBatchDifferentNonces() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permit, sig);

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);

        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permitBatch =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, 1);
        // first token nonce is 1, second token nonce is 0
        permitBatch.details[1].nonce = 0;
        bytes memory sig1 = getPermitBatchSignature(permitBatch, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permitBatch, sig1);

        (amount, expiration, nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 2);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);
    }

    function testSetAllowanceBatch() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permit =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        snapStart("permitBatchCleanWrite");
        permit2.permit(from, permit, sig);
        snapEnd();

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);
    }

    function testSetAllowanceBatchEvent() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        uint160[] memory amounts = AmountBuilder.fillUInt160(2, defaultAmount);

        IAllowanceTransfer.PermitBatch memory permit =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        // TODO: fix
        // vm.expectEmit(true, true, false, true);
        // emit Approval(from, tokens[0], address(this), amounts[0]);
        vm.expectEmit(true, true, true, true);
        emit Approval(from, tokens[1], address(this), amounts[1]);
        permit2.permit(from, permit, sig);

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);
    }

    function testSetAllowanceBatchDirtyWrite() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permit =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitBatchSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        snapStart("permitBatchDirtyWrite");
        permit2.permit(fromDirty, permit, sig);
        snapEnd();

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 2);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) =
            permit2.allowance(fromDirty, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 2);
    }

    // test setting allowance with ordered nonce and transfer
    function testSetAllowanceTransfer() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(from, permit, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));

        assertEq(amount, defaultAmount);

        permit2.transferFrom(address(token0), from, address0, defaultAmount);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testTransferFromWithGasSnapshot() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(from, permit, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));

        assertEq(amount, defaultAmount);

        snapStart("transferFrom");
        permit2.transferFrom(address(token0), from, address0, defaultAmount);

        snapEnd();
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testBatchTransferFromWithGasSnapshot() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(from, permit, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);

        // permit token0 for 1 ** 18
        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails =
            StructBuilder.fillAllowanceTransferDetail(3, address(token0), 1 ** 18, address0);
        snapStart("batchTransferFrom");
        permit2.batchTransferFrom(from, transferDetails);
        snapEnd();
        assertEq(token0.balanceOf(from), startBalanceFrom - 3 * 1 ** 18);
        assertEq(token0.balanceOf(address0), startBalanceTo + 3 * 1 ** 18);
        (amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount - 3 * 1 ** 18);
    }

    // dirty sstore on nonce, dirty sstore on transfer
    function testSetAllowanceTransferDirtyNonceDirtyTransfer() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(fromDirty);
        uint256 startBalanceTo = token0.balanceOf(address3);
        // ensure its a dirty store for the recipient address
        assertEq(startBalanceTo, defaultAmount);

        snapStart("permitDirtyNonce");
        permit2.permit(fromDirty, permit, sig);
        snapEnd();

        (uint160 amount,,) = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(amount, defaultAmount);

        permit2.transferFrom(address(token0), fromDirty, address3, defaultAmount);

        assertEq(token0.balanceOf(fromDirty), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address3), startBalanceTo + defaultAmount);
    }

    function testSetAllowanceInvalidSignature() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
        snapStart("permitInvalidSigner");
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        permit.spender = address0;
        permit2.permit(from, permit, sig);
        snapEnd();
    }

    function testSetAllowanceDeadlinePassed() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 sigDeadline = block.timestamp + 100;

        vm.warp(block.timestamp + 101);
        snapStart("permitSignatureExpired");
        vm.expectRevert(abi.encodeWithSelector(SignatureExpired.selector, sigDeadline));
        permit2.permit(from, permit, sig);
        snapEnd();
    }

    function testMaxAllowance() public {
        uint160 maxAllowance = type(uint160).max;
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), maxAllowance, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        snapStart("permitSetMaxAllowanceCleanWrite");
        permit2.permit(from, permit, sig);
        snapEnd();

        (uint160 startAllowedAmount0,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(startAllowedAmount0, type(uint160).max);

        permit2.transferFrom(address(token0), from, address0, defaultAmount);

        (uint160 endAllowedAmount0,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(endAllowedAmount0, type(uint160).max);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testMaxAllowanceDirtyWrite() public {
        uint160 maxAllowance = type(uint160).max;
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), maxAllowance, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(fromDirty);
        uint256 startBalanceTo = token0.balanceOf(address0);

        snapStart("permitSetMaxAllowanceDirtyWrite");
        permit2.permit(fromDirty, permit, sig);
        snapEnd();

        (uint160 startAllowedAmount0,,) = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(startAllowedAmount0, type(uint160).max);

        permit2.transferFrom(address(token0), fromDirty, address0, defaultAmount);

        (uint160 endAllowedAmount0,,) = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(endAllowedAmount0, type(uint160).max);

        assertEq(token0.balanceOf(fromDirty), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testPartialAllowance() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(from, permit, sig);

        (uint160 startAllowedAmount0,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(startAllowedAmount0, defaultAmount);

        uint160 transferAmount = 5 ** 18;
        permit2.transferFrom(address(token0), from, address0, transferAmount);
        (uint160 endAllowedAmount0,,) = permit2.allowance(from, address(token0), address(this));
        // ensure the allowance was deducted
        assertEq(endAllowedAmount0, defaultAmount - transferAmount);

        assertEq(token0.balanceOf(from), startBalanceFrom - transferAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + transferAmount);
    }

    function testReuseOrderedNonceInvalid() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permit, sig);
        (,, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(nonce, 1);

        (uint160 amount, uint64 expiration,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);

        vm.expectRevert(abi.encodeWithSelector(InvalidNonce.selector, defaultNonce));
        permit2.permit(from, permit, sig);
    }

    function testInvalidateNonces() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        // Invalidates the 0th nonce by setting the new nonce to 1.
        vm.prank(from);
        vm.expectEmit(true, true, true, true);
        emit NonceInvalidation(from, address(token0), address(this), 1, defaultNonce);
        permit2.invalidateNonces(address(token0), address(this), 1);
        (,, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(nonce, 1);

        vm.expectRevert(abi.encodeWithSelector(InvalidNonce.selector, defaultNonce));
        permit2.permit(from, permit, sig);
    }

    function testInvalidateMultipleNonces() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        // Valid permit, uses nonce 0.
        permit2.permit(from, permit, sig);
        (,, uint32 nonce1) = permit2.allowance(from, address(token0), address(this));
        assertEq(nonce1, 1);

        permit = defaultERC20PermitAllowance(address(token1), defaultAmount, defaultExpiration, nonce1);
        sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        // Invalidates the 9 nonces by setting the new nonce to 33.
        vm.prank(from);
        vm.expectEmit(true, true, true, true);

        emit NonceInvalidation(from, address(token0), address(this), 33, nonce1);
        permit2.invalidateNonces(address(token0), address(this), 33);
        (,, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(nonce, 33);

        vm.expectRevert(abi.encodeWithSelector(InvalidNonce.selector, nonce1));
        permit2.permit(from, permit, sig);
    }

    function testInvalidateNoncesInvalid() public {
        // fromDirty nonce is 1
        vm.prank(fromDirty);
        vm.expectRevert(abi.encodeWithSelector(InvalidNonce.selector, 0));
        // setting nonce to 0 should revert
        permit2.invalidateNonces(address(token0), address(this), 0);
    }

    function testExcessiveInvalidation() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint32 numInvalidate = type(uint16).max;
        vm.startPrank(from);
        vm.expectRevert(IAllowanceTransfer.ExcessiveInvalidation.selector);
        permit2.invalidateNonces(address(token0), address(this), numInvalidate + 1);
        vm.stopPrank();

        permit2.permit(from, permit, sig);
        (,, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(nonce, 1);
    }

    function testBatchTransferFrom() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(from, permit, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);

        // permit token0 for 1 ** 18
        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails =
            StructBuilder.fillAllowanceTransferDetail(3, address(token0), 1 ** 18, address0);

        snapStart("batchTransferFrom");
        permit2.batchTransferFrom(from, transferDetails);
        snapEnd();
        assertEq(token0.balanceOf(from), startBalanceFrom - 3 * 1 ** 18);
        assertEq(token0.balanceOf(address0), startBalanceTo + 3 * 1 ** 18);
        (amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount - 3 * 1 ** 18);
    }

    function testLockdown() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permit =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permit, sig);

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);

        IAllowanceTransfer.TokenSpenderPair[] memory approvals = new IAllowanceTransfer.TokenSpenderPair[](2);
        approvals[0] = IAllowanceTransfer.TokenSpenderPair(address(token0), address(this));
        approvals[1] = IAllowanceTransfer.TokenSpenderPair(address(token1), address(this));

        vm.prank(from);
        snapStart("lockdown");
        permit2.lockdown(approvals);
        snapEnd();

        (amount, expiration, nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, 0);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (amount1, expiration1, nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, 0);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);
    }

    function testLockdownEvent() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permit =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permit, sig);

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);

        IAllowanceTransfer.TokenSpenderPair[] memory approvals = new IAllowanceTransfer.TokenSpenderPair[](2);
        approvals[0] = IAllowanceTransfer.TokenSpenderPair(address(token0), address(this));
        approvals[1] = IAllowanceTransfer.TokenSpenderPair(address(token1), address(this));

        //TODO :fix expecting multiple events, can only check for 1
        vm.prank(from);
        vm.expectEmit(true, false, false, false);
        emit Lockdown(from, address(token0), address(this));
        permit2.lockdown(approvals);

        (amount, expiration, nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, 0);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (amount1, expiration1, nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, 0);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);
    }
}
