pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {Permit, Signature, SigType, InvalidSignature, DeadlinePassed} from "../src/Permit2Utils.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {AllowanceMath} from "../src/AllowanceMath.sol";

contract AllowanceTransferTest is Test, TokenProvider, PermitSignature {
    using AllowanceMath for uint256;

    Permit2 permit2;
    address from;
    uint256 fromPrivateKey;

    address address0 = address(0);
    address address2 = address(2);

    uint160 defaultAmount = 10 ** 18;
    uint32 defaultNonce = 1;

    function setUp() public {
        permit2 = new Permit2();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        setTestTokens(from);
        setTestTokenApprovals(vm, from, address(permit2));
    }

    // test setting allowance
    function testSetAllowance() public {
        Permit memory permit = defaultERC20PermitAllowance(address(token0), defaultAmount, defaultNonce);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        permit2.permit(permit, from, sig);

        uint256 allowance = permit2.allowance(from, address(token0), address(this));
        (uint160 amount,,) = allowance.unpack();
        assertEq(amount, defaultAmount);
    }

    // test setting allowance with ordered nonce and transfer
    function testSetAllowanceTransfer() public {
        Permit memory permit = defaultERC20PermitAllowance(address(token0), defaultAmount, defaultNonce);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        uint256 allowed = permit2.allowance(from, address(token0), address(this));
        uint160 amount = allowed.amount();

        assertEq(amount, defaultAmount);

        permit2.transferFrom(address(token0), from, address0, defaultAmount);
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testSetAllowanceInvalidSignature() public {
        Permit memory permit = defaultERC20PermitAllowance(address(token0), defaultAmount, defaultNonce);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        vm.expectRevert(InvalidSignature.selector);
        permit.spender = address0;
        permit2.permit(permit, from, sig);
    }

    function testSetAllowanceDeadlinePassed() public {
        Permit memory permit = defaultERC20PermitAllowance(address(token0), defaultAmount, defaultNonce);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        vm.warp(block.timestamp + 101);
        vm.expectRevert(DeadlinePassed.selector);
        permit2.permit(permit, from, sig);
    }

    function testMaxAllowance() public {
        uint160 maxAllowance = type(uint160).max;
        Permit memory permit = defaultERC20PermitAllowance(address(token0), maxAllowance, defaultNonce);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        uint160 startAllowedAmount0 = permit2.allowance(from, address(token0), address(this)).amount();
        assertEq(startAllowedAmount0, type(uint160).max);

        permit2.transferFrom(address(token0), from, address0, defaultAmount);
        uint160 endAllowedAmount0 = permit2.allowance(from, address(token0), address(this)).amount();
        assertEq(endAllowedAmount0, type(uint160).max);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testPartialAllowance() public {
        Permit memory permit = defaultERC20PermitAllowance(address(token0), defaultAmount, defaultNonce);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        uint160 startAllowedAmount0 = permit2.allowance(from, address(token0), address(this)).amount();
        assertEq(startAllowedAmount0, defaultAmount);

        uint160 transferAmount = 5 ** 18;
        permit2.transferFrom(address(token0), from, address0, transferAmount);

        uint160 endAllowedAmount0 = permit2.allowance(from, address(token0), address(this)).amount();
        // ensure the allowance was deducted
        assertEq(endAllowedAmount0, defaultAmount - transferAmount);

        assertEq(token0.balanceOf(from), startBalanceFrom - transferAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + transferAmount);
    }
}
