// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {SignatureVerification} from "../src/libraries/SignatureVerification.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {AllowanceTransfer} from "../src/AllowanceTransfer.sol";
import {SignatureExpired, InvalidNonce, LengthMismatch} from "../src/PermitErrors.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

contract AllowanceTransferTest is Test, TokenProvider, PermitSignature, GasSnapshot {
    using AddressBuilder for address[];
    using stdStorage for StdStorage;

    event InvalidateNonces(address indexed owner, uint32 indexed toNonce, address token, address spender);

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
        permit2.approve(address(token0), address(this), defaultAmount, defaultExpiration);

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 0);
    }

    function testSetAllowance() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        snapStart("permitCleanWrite");
        permit2.permit(permit, from, sig);
        snapEnd();

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
    }

    function testSetAllowanceDirtyWrite() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        snapStart("permitDirtyWrite");
        permit2.permit(permit, fromDirty, sig);
        snapEnd();

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 2);
    }

    function testSetAllowanceBatch() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permit =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        snapStart("permitBatchCleanWrite");
        permit2.permitBatch(permit, from, sig);
        snapEnd();

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 0);
    }

    function testSetAllowanceBatchDirtyWrite() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permit =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitBatchSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        snapStart("permitBatchDirtyWrite");
        permit2.permitBatch(permit, fromDirty, sig);
        snapEnd();

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 2);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) =
            permit2.allowance(fromDirty, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);
    }

    // test setting allowance with ordered nonce and transfer
    function testSetAllowanceTransfer() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));

        assertEq(amount, defaultAmount);

        permit2.transferFrom(address(token0), from, address0, defaultAmount);
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testTransferFromWithGasSnapshot() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));

        assertEq(amount, defaultAmount);

        snapStart("transferFrom");
        permit2.transferFrom(address(token0), from, address0, defaultAmount);
        snapEnd();
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testBatchTransferFromWithGasSnapshot() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);

        // permit token0 for 10 ** 18
        address[] memory tokens = AddressBuilder.fill(3, address(token0));
        uint160[] memory amounts = AmountBuilder.fillUInt160(3, 1 ** 18);
        address[] memory recipients = AddressBuilder.fill(3, address0);
        snapStart("batchTransferFrom");
        permit2.batchTransferFrom(tokens, from, recipients, amounts);
        snapEnd();
        assertEq(token0.balanceOf(from), startBalanceFrom - 3 * 1 ** 18);
        assertEq(token0.balanceOf(address0), startBalanceTo + 3 * 1 ** 18);
        (amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount - 3 * 1 ** 18);
    }

    // dirty sstore on nonce, dirty sstore on transfer
    function testSetAllowanceTransferDirtyNonceDirtyTransfer() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(fromDirty);
        uint256 startBalanceTo = token0.balanceOf(address3);
        // ensure its a dirty store for the recipient address
        assertEq(startBalanceTo, defaultAmount);

        snapStart("permitDirtyNonce");
        permit2.permit(permit, fromDirty, sig);
        snapEnd();

        (uint160 amount,,) = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(amount, defaultAmount);

        permit2.transferFrom(address(token0), fromDirty, address3, defaultAmount);
        assertEq(token0.balanceOf(fromDirty), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address3), startBalanceTo + defaultAmount);
    }

    function testSetAllowanceInvalidSignature() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
        snapStart("permitInvalidSigner");
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        permit.spender = address0;
        permit2.permit(permit, from, sig);
        snapEnd();
    }

    function testSetAllowanceDeadlinePassed() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        vm.warp(block.timestamp + 101);
        snapStart("permitSignatureExpired");
        vm.expectRevert(SignatureExpired.selector);
        permit2.permit(permit, from, sig);
        snapEnd();
    }

    function testMaxAllowance() public {
        uint160 maxAllowance = type(uint160).max;
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), maxAllowance, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        snapStart("permitSetMaxAllowanceCleanWrite");
        permit2.permit(permit, from, sig);
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
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), maxAllowance, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(fromDirty);
        uint256 startBalanceTo = token0.balanceOf(address0);

        snapStart("permitSetMaxAllowanceDirtyWrite");
        permit2.permit(permit, fromDirty, sig);
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
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

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
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(permit, from, sig);
        (,, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(nonce, 1);

        (uint160 amount, uint64 expiration,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);

        vm.expectRevert(InvalidNonce.selector);
        permit2.permit(permit, from, sig);
    }

    function testInvalidateNonces() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        // just need to invalidate 1 nonce on from address
        vm.prank(from);
        vm.expectEmit(true, true, false, true);
        emit InvalidateNonces(from, 1, address(token0), address(this));
        permit2.invalidateNonces(address(token0), address(this), 1);
        (,, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(nonce, 1);

        vm.expectRevert(InvalidNonce.selector);
        permit2.permit(permit, from, sig);
    }

    function testExcessiveInvalidation() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint32 numInvalidate = type(uint16).max;
        vm.startPrank(from);
        vm.expectRevert(IAllowanceTransfer.ExcessiveInvalidation.selector);
        permit2.invalidateNonces(address(token0), address(this), numInvalidate + 1);
        vm.stopPrank();

        permit2.permit(permit, from, sig);
        (,, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(nonce, 1);
    }

    function testBatchTransferFrom() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);

        // permit token0 for 10 ** 18
        address[] memory tokens = AddressBuilder.fill(3, address(token0));
        uint160[] memory amounts = AmountBuilder.fillUInt160(3, 1 ** 18);
        address[] memory recipients = AddressBuilder.fill(3, address0);

        snapStart("batchTransferFrom");
        permit2.batchTransferFrom(tokens, from, recipients, amounts);
        snapEnd();
        assertEq(token0.balanceOf(from), startBalanceFrom - 3 * 1 ** 18);
        assertEq(token0.balanceOf(address0), startBalanceTo + 3 * 1 ** 18);
        (amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount - 3 * 1 ** 18);
    }

    function testBatchTransferFromLengthMismatch() public {
        IAllowanceTransfer.Permit memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(permit, from, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);

        // permit token0 for 10 ** 18
        address[] memory tokens = AddressBuilder.fill(3, address(token0));
        uint160[] memory amounts = AmountBuilder.fillUInt160(3, 1 ** 18);
        address[] memory recipients = AddressBuilder.fill(4, address0);

        vm.expectRevert(LengthMismatch.selector);
        permit2.batchTransferFrom(tokens, from, recipients, amounts);
    }

    function testLockdown() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permit =
            defaultERC20PermitBatchAllowance(tokens, defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permitBatch(permit, from, sig);

        (uint160 amount, uint64 expiration, uint32 nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (uint160 amount1, uint64 expiration1, uint32 nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, defaultAmount);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 0);

        address[] memory tokensToLock = new address[](2);
        tokensToLock[0] = address(token0);
        tokensToLock[1] = address(token1);

        address[] memory spendersToLock = new address[](2);
        spendersToLock[0] = address(this);
        spendersToLock[1] = address(this);

        vm.prank(from);
        snapStart("lockdown");
        permit2.lockdown(tokensToLock, spendersToLock);
        snapEnd();

        (amount, expiration, nonce) = permit2.allowance(from, address(token0), address(this));
        assertEq(amount, 0);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
        (amount1, expiration1, nonce1) = permit2.allowance(from, address(token1), address(this));
        assertEq(amount1, 0);
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 0);
    }
}
