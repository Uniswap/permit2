// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {AddressBuilder} from "../utils/AddressBuilder.sol";
import {StructBuilder} from "../utils/StructBuilder.sol";
import {PermitSignature} from "../utils/PermitSignature.sol";
import {Permit2} from "../../src/Permit2.sol";
import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../../src/interfaces/ISignatureTransfer.sol";

/// @dev generic token test suite
/// @dev extend this contract with a concrete token on mainnet to test it
abstract contract MainnetTokenTest is Test, PermitSignature {
    using SafeTransferLib for ERC20;

    address constant RECIPIENT = address(0x1234123412341234123412341234123412341234);
    uint160 constant AMOUNT = 10 ** 6;
    uint48 constant NONCE = 0;
    uint48 EXPIRATION;

    address from;
    uint256 fromPrivateKey;
    bytes32 DOMAIN_SEPARATOR;
    Permit2 permit2;

    struct MockWitness {
        uint256 value;
        address person;
        bool test;
    }

    bytes32 constant FULL_EXAMPLE_WITNESS_TYPEHASH = keccak256(
        "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,MockWitness witness)MockWitness(uint256 value,address person,bool test)TokenPermissions(address token,uint256 amount)"
    );

    string constant WITNESS_TYPE_STRING =
        "MockWitness witness)MockWitness(uint256 value,address person,bool test)TokenPermissions(address token,uint256 amount)";

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL"), 15979000);

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);
        permit2 = new Permit2();
        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
        EXPIRATION = uint48(block.timestamp + 1000);

        setupToken();
    }

    function testApprove() public {
        vm.prank(from);
        permit2.approve(address(token()), address(this), AMOUNT, EXPIRATION);

        (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(token()), address(this));
        assertEq(amount, AMOUNT);
        assertEq(expiration, EXPIRATION);
        assertEq(nonce, 0);
    }

    function testPermit() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token()), AMOUNT, EXPIRATION, NONCE);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permit, sig);

        (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(token()), address(this));
        assertEq(amount, AMOUNT);
        assertEq(expiration, EXPIRATION);
        assertEq(nonce, 1);
    }

    function testTransferFrom() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token()), AMOUNT, EXPIRATION, NONCE);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token().balanceOf(from);
        uint256 startBalanceTo = token().balanceOf(RECIPIENT);

        permit2.permit(from, permit, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token()), address(this));

        assertEq(amount, AMOUNT);

        permit2.transferFrom(from, RECIPIENT, AMOUNT, address(token()));

        assertEq(token().balanceOf(from), startBalanceFrom - AMOUNT);
        assertEq(token().balanceOf(RECIPIENT), startBalanceTo + AMOUNT);
    }

    function testTransferFromInsufficientBalance() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token()), AMOUNT * 2, EXPIRATION, NONCE);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permit, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token()), address(this));
        assertEq(amount, AMOUNT * 2);

        vm.expectRevert();
        permit2.transferFrom(from, RECIPIENT, AMOUNT * 2, address(token()));
    }

    function testBatchTransferFrom() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token()), AMOUNT, EXPIRATION, NONCE);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token().balanceOf(from);
        uint256 startBalanceTo = token().balanceOf(RECIPIENT);

        permit2.permit(from, permit, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token()), address(this));
        assertEq(amount, AMOUNT);

        // permit token() for 1 ** 18
        address[] memory owners = AddressBuilder.fill(3, from);
        uint256 eachTransfer = 10 ** 5;
        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails =
            StructBuilder.fillAllowanceTransferDetail(3, address(token()), uint160(eachTransfer), RECIPIENT, owners);
        permit2.transferFrom(transferDetails);

        assertEq(token().balanceOf(from), startBalanceFrom - 3 * eachTransfer);
        assertEq(token().balanceOf(RECIPIENT), startBalanceTo + 3 * eachTransfer);
        (amount,,) = permit2.allowance(from, address(token()), address(this));
        assertEq(amount, AMOUNT - 3 * eachTransfer);
    }

    function testPermitTransferFrom() public {
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(address(token()), NONCE);
        bytes memory sig = getPermitTransferSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token().balanceOf(from);
        uint256 startBalanceTo = token().balanceOf(RECIPIENT);

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: RECIPIENT, requestedAmount: AMOUNT});

        permit2.permitTransferFrom(permit, transferDetails, from, sig);

        assertEq(token().balanceOf(from), startBalanceFrom - AMOUNT);
        assertEq(token().balanceOf(RECIPIENT), startBalanceTo + AMOUNT);
    }

    function testPermitTransferFromTypedWitness() public {
        MockWitness memory witnessData = MockWitness(10000000, address(5), true);
        bytes32 witness = keccak256(abi.encode(witnessData));
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitWitnessTransfer(address(token()), NONCE);
        bytes memory sig = getPermitWitnessTransferSignature(
            permit, fromPrivateKey, FULL_EXAMPLE_WITNESS_TYPEHASH, witness, DOMAIN_SEPARATOR
        );

        uint256 startBalanceFrom = token().balanceOf(from);
        uint256 startBalanceTo = token().balanceOf(RECIPIENT);

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: RECIPIENT, requestedAmount: AMOUNT});

        permit2.permitWitnessTransferFrom(permit, transferDetails, from, witness, WITNESS_TYPE_STRING, sig);

        assertEq(token().balanceOf(from), startBalanceFrom - AMOUNT);
        assertEq(token().balanceOf(RECIPIENT), startBalanceTo + AMOUNT);
    }

    /// @dev for some reason safeApprove gets stack too deep for USDT
    /// so helper function for setup
    function setupToken() internal virtual {
        dealTokens(from, AMOUNT);
        vm.prank(from);
        token().safeApprove(address(permit2), AMOUNT);
    }

    function token() internal virtual returns (ERC20);

    // sometimes the balances slot is not easy to find for forge
    function dealTokens(address to, uint256 amount) internal virtual {
        deal(address(token()), to, amount);
    }
}
