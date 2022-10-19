pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {Permit, Signature, SigType, InvalidSignature, DeadlinePassed, InvalidNonce} from "../src/Permit2Utils.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

contract AllowanceTransferTest is Test, TokenProvider, PermitSignature {
    using stdStorage for StdStorage;

    Permit2 permit2;
    address from;
    uint256 fromPrivateKey;

    address fromDirty;
    uint256 fromPrivateKeyDirty;

    address address0 = address(0);
    address address2 = address(2);

    // has some balance of token0
    address address3 = address(3);

    uint256 MAX_APPROVAL = type(uint256).max;
    uint256 defaultAmount = 10 ** 18;

    function setUp() public {
        permit2 = new Permit2();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        // Use this address for clean writes in setUp so we can gas test dirty writes later.
        fromPrivateKeyDirty = 0x56785678;
        fromDirty = vm.addr(fromPrivateKeyDirty);

        initializeTokens();

        setTestTokens(from);
        setTestTokenApprovals(vm, from, address(permit2));
        setTestTokens(fromDirty);
        setTestTokenApprovals(vm, fromDirty, address(permit2));

        // dirty the nonce for fromDirty address
        stdstore.target(address(permit2)).sig("nonces(address)").with_key(fromDirty).depth(0).checked_write(1);
        assertEq(permit2.nonces(fromDirty), 1);

        // ensure address3 has some balance of token0 for dirty sstore on transfer
        token0.mint(address3, 10 ** 18);
    }

    // clean sstore on nonce
    function testSetAllowanceCleanNonce() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        permit2.permit(permit, from, sig);

        uint256 allowance = permit2.allowance(from, address(token0), address(this));
        assertEq(allowance, MAX_APPROVAL);
    }

    // clean sstore on nonce, clean sstore on transfer, no refund bc allowance is still > transferred amount
    function testSetAllowanceTransferCleanNonceCleanTransfer() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);

        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);
        // ensure its a clean store for the recipient address
        assertEq(startBalanceTo, 0);

        permit2.permit(permit, from, sig);

        uint256 allowance = permit2.allowance(from, address(token0), address(this));
        assertEq(allowance, MAX_APPROVAL);

        permit2.transferFrom(address(token0), from, address0, defaultAmount);
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    // dirty sstore on nonce
    function testSetAllowanceDirtyNonce() public {
        uint256 nonce = 1;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKeyDirty, permit2.DOMAIN_SEPARATOR());

        permit2.permit(permit, fromDirty, sig);

        uint256 allowance = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(allowance, MAX_APPROVAL);
    }

    // dirty sstore on nonce, dirty sstore on transfer, no refund bc allowance > transferred amount
    function testSetAllowanceTransferDirtyNonceDirtynTransfer() public {
        uint256 nonce = 1;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKeyDirty, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceFrom = token0.balanceOf(fromDirty);
        uint256 startBalanceTo = token0.balanceOf(address3);
        // ensure its a dirty store for the recipient address
        assertEq(startBalanceTo, 10 ** 18);

        permit2.permit(permit, fromDirty, sig);

        uint256 allowance = permit2.allowance(fromDirty, address(token0), address(this));
        assertEq(allowance, MAX_APPROVAL);

        permit2.transferFrom(address(token0), fromDirty, address3, defaultAmount);
        assertEq(token0.balanceOf(fromDirty), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address3), startBalanceTo + defaultAmount);
    }

    function testUnorderedSetAllowance() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.UNORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        permit2.permit(permit, from, sig);

        uint256 allowance = permit2.allowance(from, address(token0), address(this));
        assertEq(allowance, MAX_APPROVAL);
    }

    // test setting allowance with ordered nonce and transfer
    function testUnorderedSetAllowanceTransfer() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.UNORDERED);

        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        uint256 allowance = permit2.allowance(from, address(token0), address(this));
        assertEq(allowance, MAX_APPROVAL);

        permit2.transferFrom(address(token0), from, address0, defaultAmount);
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testSetAllowanceInvalidSignature() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        vm.expectRevert(InvalidSignature.selector);
        permit.spender = address0;
        permit2.permit(permit, from, sig);
    }

    function testSetAllowanceDeadlinePassed() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        vm.warp(block.timestamp + 101);
        vm.expectRevert(DeadlinePassed.selector);
        permit2.permit(permit, from, sig);
    }

    function testReuseOrderedNonceInvalid() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        permit2.permit(permit, from, sig);

        vm.expectRevert(InvalidNonce.selector);
        permit2.permit(permit, from, sig);
    }

    function testReuseUnorderedNonceInvalid() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.UNORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        permit2.permit(permit, from, sig);

        vm.expectRevert(InvalidNonce.selector);
        permit2.permit(permit, from, sig);
    }
}
