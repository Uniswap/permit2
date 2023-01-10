// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {Permit2} from "../src/ERC20/Permit2.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {SignatureVerification} from "../src/shared/SignatureVerification.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {StructBuilder} from "./utils/StructBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {AllowanceTransfer} from "../src/ERC20/AllowanceTransfer.sol";
import {SignatureExpired, InvalidNonce} from "../src/shared/PermitErrors.sol";
import {IAllowanceTransfer} from "../src/ERC20/interfaces/IAllowanceTransfer.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

abstract contract BaseAllowanceTransferTest is Test, PermitSignature, GasSnapshot {
    using AddressBuilder for address[];
    using stdStorage for StdStorage;

    event NonceInvalidation(
        address indexed owner, address indexed token, address indexed spender, uint48 newNonce, uint48 oldNonce
    );
    event Approval(
        address indexed owner, address indexed token, address indexed spender, uint160 amount, uint48 expiration
    );
    event Permit(
        address indexed owner,
        address indexed token,
        address indexed spender,
        uint160 amount,
        uint48 expiration,
        uint48 nonce
    );
    event Lockdown(address indexed owner, address token, address spender);

    address permit2;

    address from;
    uint256 fromPrivateKey;

    address fromDirty;
    uint256 fromPrivateKeyDirty;

    address address0 = address(0);
    address address2 = address(2);

    uint160 defaultAmountOrId = 10 ** 18;
    uint48 defaultNonce = 0;
    uint32 dirtyNonce = 1;
    uint48 defaultExpiration = uint48(block.timestamp + 5);

    // has some balance of token0
    address address3 = address(3);

    bytes32 DOMAIN_SEPARATOR;

    function setUp() public virtual;

    function token0() public virtual returns (address);
    function token1() public virtual returns (address);

    function getPermitSignature(IPermitSingle memory permit, uint256 privKey, bytes32 domainSeparator)
        public
        virtual
        returns (bytes memory);

    function permit2Approve(address token, address spender, uint160 amountOrId, uint48 expiration) public virtual;

    function permit2Allowance(address from, address token, address spender)
        public
        virtual
        returns (uint160, uint48, uint48);

    function permit2Permit(address from, PermitSignature.IPermitSingle memory permit, bytes memory sig)
        public
        virtual;

    function testApprove() public {
        vm.prank(from);
        vm.expectEmit(true, true, true, true);
        emit Approval(from, token0(), address(this), defaultAmountOrId, defaultExpiration);
        permit2Approve(token0(), address(this), defaultAmountOrId, defaultExpiration);

        (uint160 amount, uint48 expiration, uint48 nonce) = permit2Allowance(from, token0(), address(this));
        assertEq(amount, defaultAmountOrId);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 0);
    }

    function testSetAllowance() public {
        // create a function defaultPermitAllowance() which will be overridden by ERC20, ERC721, and ERC1155 inherited classes
        // IPermitSingle
        PermitSignature.IPermitSingle memory permit =
            defaultPermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
        // IAllowanceTransfer.PermitSingle memory permit =
        //     defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        snapStart("permitCleanWrite");
        permit2Permit(from, permit, sig);
        snapEnd();

        (uint160 amount, uint48 expiration, uint48 nonce) = permit2Allowance(from, token0(), address(this));
        assertEq(amount, defaultAmountOrId);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
    }

    // function testSetAllowanceCompactSig() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getCompactPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
    //     assertEq(sig.length, 64);

    //     snapStart("permitCompactSig");
    //     permit2.permit(from, permit, sig);
    //     snapEnd();

    //     (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    // }

    // function testSetAllowanceIncorrectSigLength() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
    //     bytes memory sigExtra = bytes.concat(sig, bytes1(uint8(1)));
    //     assertEq(sigExtra.length, 66);

    //     vm.expectRevert(SignatureVerification.InvalidSignatureLength.selector);
    //     permit2.permit(from, permit, sigExtra);
    // }

    // function testSetAllowanceDirtyWrite() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, dirtyNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     snapStart("permitDirtyWrite");
    //     permit2.permit(fromDirty, permit, sig);
    //     snapEnd();

    //     (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(fromDirty, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 2);
    // }

    // function testSetAllowanceBatchDifferentNonces() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);

    //     address[] memory tokens = AddressBuilder.fill(1, token0()).push(token1());
    //     IAllowanceTransfer.PermitBatch memory permitBatch =
    //         defaultERC20PermitBatchAllowance(tokens, defaultAmountOrId, defaultExpiration, 1);
    //     // first token nonce is 1, second token nonce is 0
    //     permitBatch.details[1].nonce = 0;
    //     bytes memory sig1 = getPermitBatchSignature(permitBatch, fromPrivateKey, DOMAIN_SEPARATOR);

    //     permit2.permit(from, permitBatch, sig1);

    //     (amount, expiration, nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 2);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount1, defaultAmountOrId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }

    // function testSetAllowanceBatch() public {
    //     address[] memory tokens = AddressBuilder.fill(1, token0()).push(token1());
    //     IAllowanceTransfer.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     snapStart("permitBatchCleanWrite");
    //     permit2.permit(from, permit, sig);
    //     snapEnd();

    //     (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount1, defaultAmountOrId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }

    // function testSetAllowanceBatchEvent() public {
    //     address[] memory tokens = AddressBuilder.fill(1, token0()).push(token1());
    //     uint160[] memory amounts = AmountBuilder.fillUInt160(2, defaultAmountOrId);

    //     IAllowanceTransfer.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     vm.expectEmit(true, true, true, true);
    //     emit Permit(from, tokens[0], address(this), amounts[0], defaultExpiration, defaultNonce);
    //     vm.expectEmit(true, true, true, true);
    //     emit Permit(from, tokens[1], address(this), amounts[1], defaultExpiration, defaultNonce);
    //     permit2.permit(from, permit, sig);

    //     (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount1, defaultAmountOrId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }

    // function testSetAllowanceBatchDirtyWrite() public {
    //     address[] memory tokens = AddressBuilder.fill(1, token0()).push(token1());
    //     IAllowanceTransfer.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultAmountOrId, defaultExpiration, dirtyNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     snapStart("permitBatchDirtyWrite");
    //     permit2.permit(fromDirty, permit, sig);
    //     snapEnd();

    //     (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(fromDirty, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 2);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(fromDirty, token1(), address(this));
    //     assertEq(amount1, defaultAmountOrId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 2);
    // }

    // // test setting allowance with ordered nonce and transfer
    // function testSetAllowanceTransfer() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount,,) = permit2.allowance(from, token0(), address(this));

    //     assertEq(amount, defaultAmountOrId);

    //     permit2.transferFrom(from, address0, defaultAmountOrId, token0());

    //     assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmountOrId);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmountOrId);
    // }

    // function testTransferFromWithGasSnapshot() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount,,) = permit2.allowance(from, token0(), address(this));

    //     assertEq(amount, defaultAmountOrId);

    //     snapStart("transferFrom");
    //     permit2.transferFrom(from, address0, defaultAmountOrId, token0());

    //     snapEnd();
    //     assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmountOrId);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmountOrId);
    // }

    // function testBatchTransferFromWithGasSnapshot() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);

    //     // permit token0 for 1 ** 18
    //     address[] memory owners = AddressBuilder.fill(3, from);
    //     IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails =
    //         StructBuilder.fillAllowanceTransferDetail(3, token0(), 1 ** 18, address0, owners);
    //     snapStart("batchTransferFrom");
    //     permit2.transferFrom(transferDetails);
    //     snapEnd();
    //     assertEq(token0.balanceOf(from), startBalanceFrom - 3 * 1 ** 18);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + 3 * 1 ** 18);
    //     (amount,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId - 3 * 1 ** 18);
    // }

    // // dirty sstore on nonce, dirty sstore on transfer
    // function testSetAllowanceTransferDirtyNonceDirtyTransfer() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, dirtyNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(fromDirty);
    //     uint256 startBalanceTo = token0.balanceOf(address3);
    //     // ensure its a dirty store for the recipient address
    //     assertEq(startBalanceTo, defaultAmountOrId);

    //     snapStart("permitDirtyNonce");
    //     permit2.permit(fromDirty, permit, sig);
    //     snapEnd();

    //     (uint160 amount,,) = permit2.allowance(fromDirty, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);

    //     permit2.transferFrom(fromDirty, address3, defaultAmountOrId, token0());

    //     assertEq(token0.balanceOf(fromDirty), startBalanceFrom - defaultAmountOrId);
    //     assertEq(token0.balanceOf(address3), startBalanceTo + defaultAmountOrId);
    // }

    // function testSetAllowanceInvalidSignature() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
    //     snapStart("permitInvalidSigner");
    //     vm.expectRevert(SignatureVerification.InvalidSigner.selector);
    //     permit.spender = address0;
    //     permit2.permit(from, permit, sig);
    //     snapEnd();
    // }

    // function testSetAllowanceDeadlinePassed() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 sigDeadline = block.timestamp + 100;

    //     vm.warp(block.timestamp + 101);
    //     snapStart("permitSignatureExpired");
    //     vm.expectRevert(abi.encodeWithSelector(SignatureExpired.selector, sigDeadline));
    //     permit2.permit(from, permit, sig);
    //     snapEnd();
    // }

    // function testMaxAllowance() public {
    //     uint160 maxAllowance = type(uint160).max;
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), maxAllowance, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     snapStart("permitSetMaxAllowanceCleanWrite");
    //     permit2.permit(from, permit, sig);
    //     snapEnd();

    //     (uint160 startAllowedAmount0,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(startAllowedAmount0, type(uint160).max);

    //     permit2.transferFrom(from, address0, defaultAmountOrId, token0());

    //     (uint160 endAllowedAmount0,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(endAllowedAmount0, type(uint160).max);

    //     assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmountOrId);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmountOrId);
    // }

    // function testMaxAllowanceDirtyWrite() public {
    //     uint160 maxAllowance = type(uint160).max;
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), maxAllowance, defaultExpiration, dirtyNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(fromDirty);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     snapStart("permitSetMaxAllowanceDirtyWrite");
    //     permit2.permit(fromDirty, permit, sig);
    //     snapEnd();

    //     (uint160 startAllowedAmount0,,) = permit2.allowance(fromDirty, token0(), address(this));
    //     assertEq(startAllowedAmount0, type(uint160).max);

    //     permit2.transferFrom(fromDirty, address0, defaultAmountOrId, token0());

    //     (uint160 endAllowedAmount0,,) = permit2.allowance(fromDirty, token0(), address(this));
    //     assertEq(endAllowedAmount0, type(uint160).max);

    //     assertEq(token0.balanceOf(fromDirty), startBalanceFrom - defaultAmountOrId);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmountOrId);
    // }

    // function testPartialAllowance() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 startAllowedAmount0,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(startAllowedAmount0, defaultAmountOrId);

    //     uint160 transferAmount = 5 ** 18;
    //     permit2.transferFrom(from, address0, transferAmount, token0());
    //     (uint160 endAllowedAmount0,,) = permit2.allowance(from, token0(), address(this));
    //     // ensure the allowance was deducted
    //     assertEq(endAllowedAmount0, defaultAmountOrId - transferAmount);

    //     assertEq(token0.balanceOf(from), startBalanceFrom - transferAmount);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + transferAmount);
    // }

    // function testReuseOrderedNonceInvalid() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     permit2.permit(from, permit, sig);
    //     (,, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(nonce, 1);

    //     (uint160 amount, uint48 expiration,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);

    //     vm.expectRevert(InvalidNonce.selector);
    //     permit2.permit(from, permit, sig);
    // }

    // function testInvalidateNonces() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     // Invalidates the 0th nonce by setting the new nonce to 1.
    //     vm.prank(from);
    //     vm.expectEmit(true, true, true, true);
    //     emit NonceInvalidation(from, token0(), address(this), 1, defaultNonce);
    //     permit2.invalidateNonces(token0(), address(this), 1);
    //     (,, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(nonce, 1);

    //     vm.expectRevert(InvalidNonce.selector);
    //     permit2.permit(from, permit, sig);
    // }

    // function testInvalidateMultipleNonces() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     // Valid permit, uses nonce 0.
    //     permit2.permit(from, permit, sig);
    //     (,, uint48 nonce1) = permit2.allowance(from, token0(), address(this));
    //     assertEq(nonce1, 1);

    //     permit = defaultERC20PermitAllowance(token1(), defaultAmountOrId, defaultExpiration, nonce1);
    //     sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     // Invalidates the 9 nonces by setting the new nonce to 33.
    //     vm.prank(from);
    //     vm.expectEmit(true, true, true, true);

    //     emit NonceInvalidation(from, token0(), address(this), 33, nonce1);
    //     permit2.invalidateNonces(token0(), address(this), 33);
    //     (,, uint48 nonce2) = permit2.allowance(from, token0(), address(this));
    //     assertEq(nonce2, 33);

    //     vm.expectRevert(InvalidNonce.selector);
    //     permit2.permit(from, permit, sig);
    // }

    // function testInvalidateNoncesInvalid() public {
    //     // fromDirty nonce is 1
    //     vm.prank(fromDirty);
    //     vm.expectRevert(InvalidNonce.selector);
    //     // setting nonce to 0 should revert
    //     permit2.invalidateNonces(token0(), address(this), 0);
    // }

    // function testExcessiveInvalidation() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint32 numInvalidate = type(uint16).max;
    //     vm.startPrank(from);
    //     vm.expectRevert(IAllowanceTransfer.ExcessiveInvalidation.selector);
    //     permit2.invalidateNonces(token0(), address(this), numInvalidate + 1);
    //     vm.stopPrank();

    //     permit2.permit(from, permit, sig);
    //     (,, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(nonce, 1);
    // }

    // function testBatchTransferFrom() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);

    //     // permit token0 for 1 ** 18
    //     address[] memory owners = AddressBuilder.fill(3, from);
    //     IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails =
    //         StructBuilder.fillAllowanceTransferDetail(3, token0(), 1 ** 18, address0, owners);
    //     snapStart("batchTransferFrom");
    //     permit2.transferFrom(transferDetails);
    //     snapEnd();
    //     assertEq(token0.balanceOf(from), startBalanceFrom - 3 * 1 ** 18);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + 3 * 1 ** 18);
    //     (amount,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId - 3 * 1 ** 18);
    // }

    // function testBatchTransferFromMultiToken() public {
    //     address[] memory tokens = AddressBuilder.fill(1, token0()).push(token1());
    //     IAllowanceTransfer.PermitBatch memory permitBatch =
    //         defaultERC20PermitBatchAllowance(tokens, defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permitBatch, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom0 = token0.balanceOf(from);
    //     uint256 startBalanceFrom1 = token1.balanceOf(from);
    //     uint256 startBalanceTo0 = token0.balanceOf(address0);
    //     uint256 startBalanceTo1 = token1.balanceOf(address0);

    //     permit2.permit(from, permitBatch, sig);

    //     (uint160 amount,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     (amount,,) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount, defaultAmountOrId);

    //     // permit token0 for 1 ** 18
    //     address[] memory owners = AddressBuilder.fill(2, from);
    //     IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails =
    //         StructBuilder.fillAllowanceTransferDetail(2, tokens, 1 ** 18, address0, owners);
    //     snapStart("batchTransferFromMultiToken");
    //     permit2.transferFrom(transferDetails);
    //     snapEnd();
    //     assertEq(token0.balanceOf(from), startBalanceFrom0 - 1 ** 18);
    //     assertEq(token1.balanceOf(from), startBalanceFrom1 - 1 ** 18);
    //     assertEq(token0.balanceOf(address0), startBalanceTo0 + 1 ** 18);
    //     assertEq(token1.balanceOf(address0), startBalanceTo1 + 1 ** 18);
    //     (amount,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId - 1 ** 18);
    //     (amount,,) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount, defaultAmountOrId - 1 ** 18);
    // }

    // function testBatchTransferFromDifferentOwners() public {
    //     IAllowanceTransfer.PermitSingle memory permit =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     IAllowanceTransfer.PermitSingle memory permitDirty =
    //         defaultERC20PermitAllowance(token0(), defaultAmountOrId, defaultExpiration, dirtyNonce);
    //     bytes memory sigDirty = getPermitSignature(permitDirty, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address(this));
    //     uint256 startBalanceFromDirty = token0.balanceOf(fromDirty);

    //     // from and fromDirty approve address(this) as spender
    //     permit2.permit(from, permit, sig);
    //     permit2.permit(fromDirty, permitDirty, sigDirty);

    //     (uint160 amount,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     (uint160 amount1,,) = permit2.allowance(fromDirty, token0(), address(this));
    //     assertEq(amount1, defaultAmountOrId);

    //     address[] memory owners = AddressBuilder.fill(1, from).push(fromDirty);
    //     IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails =
    //         StructBuilder.fillAllowanceTransferDetail(2, token0(), 1 ** 18, address(this), owners);
    //     snapStart("transferFrom with different owners");
    //     permit2.transferFrom(transferDetails);
    //     snapEnd();

    //     assertEq(token0.balanceOf(from), startBalanceFrom - 1 ** 18);
    //     assertEq(token0.balanceOf(fromDirty), startBalanceFromDirty - 1 ** 18);
    //     assertEq(token0.balanceOf(address(this)), startBalanceTo + 2 * 1 ** 18);
    //     (amount,,) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId - 1 ** 18);
    //     (amount,,) = permit2.allowance(fromDirty, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId - 1 ** 18);
    // }

    // function testLockdown() public {
    //     address[] memory tokens = AddressBuilder.fill(1, token0()).push(token1());
    //     IAllowanceTransfer.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount1, defaultAmountOrId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);

    //     IAllowanceTransfer.TokenSpenderPair[] memory approvals = new IAllowanceTransfer.TokenSpenderPair[](2);
    //     approvals[0] = IAllowanceTransfer.TokenSpenderPair(token0(), address(this));
    //     approvals[1] = IAllowanceTransfer.TokenSpenderPair(token1(), address(this));

    //     vm.prank(from);
    //     snapStart("lockdown");
    //     permit2.lockdown(approvals);
    //     snapEnd();

    //     (amount, expiration, nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, 0);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (amount1, expiration1, nonce1) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount1, 0);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }

    // function testLockdownEvent() public {
    //     address[] memory tokens = AddressBuilder.fill(1, token0()).push(token1());
    //     IAllowanceTransfer.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultAmountOrId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount, uint48 expiration, uint48 nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, defaultAmountOrId);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount1, defaultAmountOrId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);

    //     IAllowanceTransfer.TokenSpenderPair[] memory approvals = new IAllowanceTransfer.TokenSpenderPair[](2);
    //     approvals[0] = IAllowanceTransfer.TokenSpenderPair(token0(), address(this));
    //     approvals[1] = IAllowanceTransfer.TokenSpenderPair(token1(), address(this));

    //     //TODO :fix expecting multiple events, can only check for 1
    //     vm.prank(from);
    //     vm.expectEmit(true, false, false, false);
    //     emit Lockdown(from, token0(), address(this));
    //     permit2.lockdown(approvals);

    //     (amount, expiration, nonce) = permit2.allowance(from, token0(), address(this));
    //     assertEq(amount, 0);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (amount1, expiration1, nonce1) = permit2.allowance(from, token1(), address(this));
    //     assertEq(amount1, 0);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }
}
