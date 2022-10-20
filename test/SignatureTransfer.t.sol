// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {Permit2} from "../src/Permit2.sol";
import {
    PermitTransfer,
    PermitBatchTransfer,
    LengthMismatch,
    InvalidNonce,
    RecipientLengthMismatch,
    AmountsLengthMismatch
} from "../src/Permit2Utils.sol";
import {SignatureTransfer} from "../src/SignatureTransfer.sol";

contract SignatureTransferTest is Test, PermitSignature, TokenProvider {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    Permit2 permit2;

    address from;
    uint256 fromPrivateKey;
    uint256 defaultAmount = 10 ** 18;

    address address0 = address(0x0);
    address address2 = address(0x2);

    bytes32 DOMAIN_SEPARATOR;

    function setUp() public {
        permit2 = new Permit2();
        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        initializeTokens();

        setTestTokens(from);
        setTestTokenApprovals(vm, from, address(permit2));
    }

    function testPermitTransferFrom() public {
        uint256 nonce = 0;
        PermitTransfer memory permit = defaultERC20PermitTransfer(address(token0), nonce);
        bytes memory sig = getPermitTransferSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        permit2.permitTransferFrom(permit, from, address2, defaultAmount, sig);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address2), startBalanceTo + defaultAmount);
    }

    function testPermitTransferFromToSpender() public {
        uint256 nonce = 0;
        // signed spender is address(this)
        PermitTransfer memory permit = defaultERC20PermitTransfer(address(token0), nonce);
        bytes memory sig = getPermitTransferSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceAddr0 = token0.balanceOf(address0);
        uint256 startBalanceTo = token0.balanceOf(address(this));

        // if to is address0, tokens sent to signed spender
        permit2.permitTransferFrom(permit, from, address0, defaultAmount, sig);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address(this)), startBalanceTo + defaultAmount);
        // should not effect address0
        assertEq(token0.balanceOf(address0), startBalanceAddr0);
    }

    function testPermitTransferFromInvalidNonce() public {
        uint256 nonce = 0;
        PermitTransfer memory permit = defaultERC20PermitTransfer(address(token0), nonce);
        bytes memory sig = getPermitTransferSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permitTransferFrom(permit, from, address2, defaultAmount, sig);

        vm.expectRevert(InvalidNonce.selector);
        permit2.permitTransferFrom(permit, from, address2, defaultAmount, sig);
    }

    function testPermitBatchTransferFrom() public {
        uint256 nonce = 0;
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        PermitBatchTransfer memory permit = defaultERC20PermitMultiple(tokens, nonce);
        bytes memory sig = getPermitBatchSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        address[] memory to = AddressBuilder.fill(1, address(address2)).push(address(address0));
        uint256[] memory amounts = AmountBuilder.fill(2, defaultAmount);

        uint256 startBalanceFrom0 = token0.balanceOf(from);
        uint256 startBalanceFrom1 = token1.balanceOf(from);
        uint256 startBalanceTo0 = token0.balanceOf(address2);
        uint256 startBalanceTo1 = token1.balanceOf(address0);

        permit2.permitBatchTransferFrom(permit, from, to, amounts, sig);

        assertEq(token0.balanceOf(from), startBalanceFrom0 - defaultAmount);
        assertEq(token1.balanceOf(from), startBalanceFrom1 - defaultAmount);
        assertEq(token0.balanceOf(address2), startBalanceTo0 + defaultAmount);
        assertEq(token1.balanceOf(address0), startBalanceTo1 + defaultAmount);
    }

    function testPermitBatchTransferFromSingleRecipient() public {
        uint256 nonce = 0;
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        PermitBatchTransfer memory permit = defaultERC20PermitMultiple(tokens, nonce);
        bytes memory sig = getPermitBatchSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        address[] memory to = AddressBuilder.fill(1, address(address2));
        uint256[] memory amounts = AmountBuilder.fill(2, defaultAmount);

        uint256 startBalanceFrom0 = token0.balanceOf(from);
        uint256 startBalanceFrom1 = token1.balanceOf(from);
        uint256 startBalanceTo0 = token0.balanceOf(address2);
        uint256 startBalanceTo1 = token1.balanceOf(address2);

        permit2.permitBatchTransferFrom(permit, from, to, amounts, sig);

        assertEq(token0.balanceOf(from), startBalanceFrom0 - defaultAmount);
        assertEq(token1.balanceOf(from), startBalanceFrom1 - defaultAmount);
        assertEq(token0.balanceOf(address2), startBalanceTo0 + defaultAmount);
        assertEq(token1.balanceOf(address2), startBalanceTo1 + defaultAmount);
    }

    function testPermitBatchTransferMultiAddr() public {
        uint256 nonce = 0;
        // signed spender is address(this)
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        PermitBatchTransfer memory permit = defaultERC20PermitMultiple(tokens, nonce);
        bytes memory sig = getPermitBatchSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom0 = token0.balanceOf(from);
        uint256 startBalanceFrom1 = token1.balanceOf(from);
        uint256 startBalanceTo0 = token0.balanceOf(address(this));
        uint256 startBalanceTo1 = token1.balanceOf(address2);

        address[] memory to = AddressBuilder.fill(1, address(this)).push(address2);
        uint256[] memory amounts = AmountBuilder.fill(2, defaultAmount);
        permit2.permitBatchTransferFrom(permit, from, to, amounts, sig);

        assertEq(token0.balanceOf(from), startBalanceFrom0 - defaultAmount);
        assertEq(token0.balanceOf(address(this)), startBalanceTo0 + defaultAmount);

        assertEq(token1.balanceOf(from), startBalanceFrom1 - defaultAmount);
        assertEq(token1.balanceOf(address2), startBalanceTo1 + defaultAmount);
    }

    function testPermitBatchTransferSingleAddr() public {
        uint256 nonce = 0;

        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        PermitBatchTransfer memory permit = defaultERC20PermitMultiple(tokens, nonce);
        bytes memory sig = getPermitBatchSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom0 = token0.balanceOf(from);
        uint256 startBalanceFrom1 = token1.balanceOf(from);
        uint256 startBalanceTo0 = token0.balanceOf(address(this));
        uint256 startBalanceTo1 = token1.balanceOf(address(this));

        address[] memory to = AddressBuilder.fill(1, address(this));
        uint256[] memory amounts = AmountBuilder.fill(2, defaultAmount);
        permit2.permitBatchTransferFrom(permit, from, to, amounts, sig);

        assertEq(token0.balanceOf(from), startBalanceFrom0 - defaultAmount);
        assertEq(token0.balanceOf(address(this)), startBalanceTo0 + defaultAmount);

        assertEq(token1.balanceOf(from), startBalanceFrom1 - defaultAmount);
        assertEq(token1.balanceOf(address(this)), startBalanceTo1 + defaultAmount);
    }

    function testPermitBatchTransferInvalidSingleAddr() public {
        uint256 nonce = 0;

        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        PermitBatchTransfer memory permit = defaultERC20PermitMultiple(tokens, nonce);
        bytes memory sig = getPermitBatchSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        address[] memory to = AddressBuilder.fill(1, address(this));
        uint256[] memory amounts = AmountBuilder.fill(1, defaultAmount);

        vm.expectRevert(AmountsLengthMismatch.selector);
        permit2.permitBatchTransferFrom(permit, from, to, amounts, sig);
    }

    function testPermitBatchTransferInvalidAmountsLength() public {
        uint256 nonce = 0;

        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        PermitBatchTransfer memory permit = defaultERC20PermitMultiple(tokens, nonce);
        bytes memory sig = getPermitBatchSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        address[] memory to = AddressBuilder.fill(2, address(this));
        uint256[] memory amounts = AmountBuilder.fill(3, defaultAmount);

        vm.expectRevert(AmountsLengthMismatch.selector);
        permit2.permitBatchTransferFrom(permit, from, to, amounts, sig);
    }

    function testPermitBatchTransferInvalidRecipientsLength() public {
        uint256 nonce = 0;

        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        PermitBatchTransfer memory permit = defaultERC20PermitMultiple(tokens, nonce);
        bytes memory sig = getPermitBatchSignature(vm, permit, fromPrivateKey, DOMAIN_SEPARATOR);

        address[] memory to = AddressBuilder.fill(3, address(this));
        uint256[] memory amounts = AmountBuilder.fill(2, defaultAmount);

        vm.expectRevert(RecipientLengthMismatch.selector);
        permit2.permitBatchTransferFrom(permit, from, to, amounts, sig);
    }
}
