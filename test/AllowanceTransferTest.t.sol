pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {Permit, Signature, SigType, InvalidSignature, DeadlinePassed} from "../src/Permit2Utils.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";

contract AllowanceTransferTest is Test, TokenProvider, PermitSignature {
    Permit2 permit2;
    address from;
    uint256 fromPrivateKey;

    address address0 = address(0);
    address address2 = address(2);

    uint256 defaultAmount = 10 ** 18;

    function setUp() public {
        permit2 = new Permit2();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        setTestTokens(from);
        setTestTokenApprovals(vm, from, address(permit2));
    }

    // test setting allowance with ordered nonce
    function testSetAllowance() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        permit2.permit(permit, from, sig);

        uint256 allowance = permit2.allowance(from, address(token0), address(this));
        assertEq(allowance, defaultAmount);
    }

    // test setting allowance with ordered nonce and transfer
    function testSetAllowanceTransfer() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);

        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(permit, from, sig);

        uint256 allowance = permit2.allowance(from, address(token0), address(this));
        assertEq(allowance, defaultAmount);

        permit2.transferFrom(address(token0), from, address0, defaultAmount);
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testUnorderedSetAllowance() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.UNORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        permit2.permit(permit, from, sig);

        uint256 allowance = permit2.allowance(from, address(token0), address(this));
        assertEq(allowance, defaultAmount);
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
        assertEq(allowance, defaultAmount);

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

    function testSetAllowanceLengthMismatch() public {
        uint256 nonce = 0;
        Permit memory permit = defaultERC20Permit(address(token0), nonce, SigType.ORDERED);
        Signature memory sig = getPermitSignature(vm, permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        vm.warp(block.timestamp + 101);
        vm.expectRevert(DeadlinePassed.selector);
        permit2.permit(permit, from, sig);
    }
}
