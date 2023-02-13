// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2ERC721} from "../src/ERC721/Permit2ERC721.sol";
import {PermitSignatureERC721} from "./utils/PermitSignatureERC721.sol";
import {SignatureVerification} from "../src/ERC20/SignatureVerification.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {StructBuilder} from "./utils/StructBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {AllowanceTransferERC721} from "../src/ERC721/AllowanceTransferERC721.sol";
import {SignatureExpired, InvalidNonce} from "../src/ERC721/PermitErrors.sol";
import {IAllowanceTransferERC721} from "../src/ERC721/interfaces/IAllowanceTransferERC721.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {MockERC721} from "./mocks/MockERC721.sol";

contract AllowanceTransferTestERC721 is Test, TokenProvider, PermitSignatureERC721, GasSnapshot {
    using AddressBuilder for address[];
    using stdStorage for StdStorage;

    event NonceInvalidation(
        address indexed owner, address indexed token, address indexed spender, uint48 newNonce, uint48 oldNonce
    );
    event Approval(
        address indexed owner, address indexed token, address indexed spender, uint256 tokenId, uint48 expiration
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

    Permit2ERC721 permit2;

    address from;
    uint256 fromPrivateKey;

    address fromDirty;
    uint256 fromPrivateKeyDirty;

    address address0 = address(0);
    address address2 = address(2);

    uint256 defaultTokenId = 0;
    uint48 defaultNonce = 0;
    uint32 dirtyNonce = 1;
    uint48 defaultExpiration = uint48(block.timestamp + 5);

    MockERC721 nft1;
    MockERC721 nft2;
    MockERC721 nftDirty;

    // has some balance of token0
    address address3 = address(3);

    bytes32 DOMAIN_SEPARATOR;

    function setUp() public {
        permit2 = new Permit2ERC721();
        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        // Use this address to gas test dirty writes later.
        fromPrivateKeyDirty = 0x56785678;
        fromDirty = vm.addr(fromPrivateKeyDirty);

        // seed with 3 nfts
        uint256 fromNFTAmount = 3;
        initializeForOwner(fromNFTAmount, from);
        initializeERC721TokensAndApprove(vm, from, address(permit2), fromNFTAmount);

        nft1 = getNFT(from, 0);
        nft2 = getNFT(from, 1);

        initializeForOwner(1, fromDirty);
        initializeERC721TokensAndApprove(vm, fromDirty, address(permit2), 1);
        nftDirty = getNFT(fromDirty, 0);

        // dirty the nonce for fromDirty address on nft1
        vm.startPrank(fromDirty);
        permit2.invalidateNonces(address(getNFT(fromDirty, 0)), 0, 1);
        vm.stopPrank();
    }

    function testERC721Approve() public {
        vm.prank(from);
        vm.expectEmit(true, true, true, true);
        emit Approval(from, address(nft1), address(this), defaultTokenId, defaultExpiration);
        permit2.approve(address(nft1), address(this), defaultTokenId, defaultExpiration);

        (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
        assertEq(spender, address(this));
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 0);
    }

    function testERC721SetAllowance() public {
        IAllowanceTransferERC721.PermitSingle memory permit =
            defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        snapStart("permitCleanWrite");
        permit2.permit(from, permit, sig);
        snapEnd();

        (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
        assertEq(spender, address(this));
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
    }

    function testERC721SetAllowanceAndTransfer() public {
        IAllowanceTransferERC721.PermitSingle memory permit =
            defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permit, sig);

        (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
        assertEq(spender, address(this)); // spender address is reset
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);

        permit2.transferFrom(from, address2, defaultTokenId, address(nft1));

        (spender, expiration, nonce) = permit2.allowance(from, address(nft1), defaultTokenId);

        assertEq(spender, address(0)); // spender address is reset
        assertEq(expiration, 0); // expiration is reset
        assertEq(nonce, 1);
        assertEq(nft1.balanceOf(from), 0);
        assertEq(nft1.balanceOf(address2), 1);
    }

    function testERC721SetAllowanceCompactSig() public {
        IAllowanceTransferERC721.PermitSingle memory permit =
            defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
        bytes memory sig = getCompactPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
        assertEq(sig.length, 64);

        snapStart("permitCompactSig");
        permit2.permit(from, permit, sig);
        snapEnd();

        (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
        assertEq(spender, address(this));
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
    }

    function testERC721SetAllowanceIncorrectSigLength() public {
        IAllowanceTransferERC721.PermitSingle memory permit =
            defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
        bytes memory sigExtra = bytes.concat(sig, bytes1(uint8(1)));
        assertEq(sigExtra.length, 66);

        vm.expectRevert(SignatureVerification.InvalidSignatureLength.selector);
        permit2.permit(from, permit, sigExtra);
    }

    function testERC721SetAllowanceDirtyWrite() public {
        IAllowanceTransferERC721.PermitSingle memory permit =
            defaultERC721PermitAllowance(address(nftDirty), defaultTokenId, defaultExpiration, dirtyNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

        snapStart("permitDirtyWrite");
        permit2.permit(fromDirty, permit, sig);
        snapEnd();

        (address spender, uint48 expiration, uint48 nonce) =
            permit2.allowance(fromDirty, address(nftDirty), defaultTokenId);
        assertEq(spender, address(this));
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 2);
    }

    function testERC721SetAllowanceBatchDifferentNonces() public {
        IAllowanceTransferERC721.PermitSingle memory permit =
            defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permit, sig);

        (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
        assertEq(spender, address(this));
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);

        address[] memory tokens = AddressBuilder.fill(1, address(nft1)).push(address(nft2));
        IAllowanceTransferERC721.PermitBatch memory permitBatch =
            defaultERC20PermitBatchAllowance(tokens, defaultExpiration, 1);
        // first token nonce is 1, second token nonce is 0
        permitBatch.details[1].nonce = 0;
        bytes memory sig1 = getPermitBatchSignature(permitBatch, fromPrivateKey, DOMAIN_SEPARATOR);

        permit2.permit(from, permitBatch, sig1);

        (spender, expiration, nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
        assertEq(spender, address(this));
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 2);
        (address spender1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, address(nft2), 1);
        assertEq(spender1, address(this));
        assertEq(expiration1, defaultExpiration);
        assertEq(nonce1, 1);
    }

    // TODO add more test coverage, copied over from erc20 testsuite

    // function testERC721SetAllowanceBatch() public {
    //     address[] memory tokens = AddressBuilder.fill(1, address(nft1)).push(address(token1));
    //     IAllowanceTransferERC721.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     snapStart("permitBatchCleanWrite");
    //     permit2.permit(from, permit, sig);
    //     snapEnd();

    //     (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, address(token1), address(this));
    //     assertEq(amount1, defaultTokenId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }

    // function testERC721SetAllowanceBatchEvent() public {
    //     address[] memory tokens = AddressBuilder.fill(1, address(nft1)).push(address(token1));
    //     uint160[] memory amounts = AmountBuilder.fillUInt160(2, defaultTokenId);

    //     IAllowanceTransferERC721.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     vm.expectEmit(true, true, true, true);
    //     emit Permit(from, tokens[0], address(this), amounts[0], defaultExpiration, defaultNonce);
    //     vm.expectEmit(true, true, true, true);
    //     emit Permit(from, tokens[1], address(this), amounts[1], defaultExpiration, defaultNonce);
    //     permit2.permit(from, permit, sig);

    //     (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, address(token1), address(this));
    //     assertEq(amount1, defaultTokenId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }

    // function testERC721SetAllowanceBatchDirtyWrite() public {
    //     address[] memory tokens = AddressBuilder.fill(1, address(nft1)).push(address(token1));
    //     IAllowanceTransferERC721.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultTokenId, defaultExpiration, dirtyNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     snapStart("permitBatchDirtyWrite");
    //     permit2.permit(fromDirty, permit, sig);
    //     snapEnd();

    //     (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(fromDirty, address(nft1), address(this));
    //     assertEq(spender, address(this));
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 2);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) =
    //         permit2.allowance(fromDirty, address(token1), address(this));
    //     assertEq(amount1, defaultTokenId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 2);
    // }

    // // test setting allowance with ordered nonce and transfer
    // function testERC721SetAllowanceTransfer() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);

    //     assertEq(spender, address(this));

    //     permit2.transferFrom(from, address0, defaultTokenId, address(nft1));

    //     assertEq(token0.balanceOf(from), startBalanceFrom - defaultTokenId);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + defaultTokenId);
    // }

    // function testERC721TransferFromWithGasSnapshot() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);

    //     assertEq(spender, address(this));

    //     snapStart("transferFrom");
    //     permit2.transferFrom(from, address0, defaultTokenId, address(nft1));

    //     snapEnd();
    //     assertEq(token0.balanceOf(from), startBalanceFrom - defaultTokenId);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + defaultTokenId);
    // }

    // function testERC721BatchTransferFromWithGasSnapshot() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));

    //     // permit token0 for 1 ** 18
    //     address[] memory owners = AddressBuilder.fill(3, from);
    //     IAllowanceTransferERC721.AllowanceTransferDetails[] memory transferDetails =
    //         StructBuilder.fillAllowanceTransferDetail(3, address(nft1), 1 ** 18, address0, owners);
    //     snapStart("batchTransferFrom");
    //     permit2.transferFrom(transferDetails);
    //     snapEnd();
    //     assertEq(token0.balanceOf(from), startBalanceFrom - 3 * 1 ** 18);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + 3 * 1 ** 18);
    //     (amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(amount, defaultTokenId - 3 * 1 ** 18);
    // }

    // // dirty sstore on nonce, dirty sstore on transfer
    // function testERC721SetAllowanceTransferDirtyNonceDirtyTransfer() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, dirtyNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(fromDirty);
    //     uint256 startBalanceTo = token0.balanceOf(address3);
    //     // ensure its a dirty store for the recipient address
    //     assertEq(startBalanceTo, defaultTokenId);

    //     snapStart("permitDirtyNonce");
    //     permit2.permit(fromDirty, permit, sig);
    //     snapEnd();

    //     (uint160 amount,,) = permit2.allowance(fromDirty, address(nft1), address(this));
    //     assertEq(spender, address(this));

    //     permit2.transferFrom(fromDirty, address3, defaultTokenId, address(nft1));

    //     assertEq(token0.balanceOf(fromDirty), startBalanceFrom - defaultTokenId);
    //     assertEq(token0.balanceOf(address3), startBalanceTo + defaultTokenId);
    // }

    // function testERC721SetAllowanceInvalidSignature() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
    //     snapStart("permitInvalidSigner");
    //     vm.expectRevert(SignatureVerification.InvalidSigner.selector);
    //     permit.spender = address0;
    //     permit2.permit(from, permit, sig);
    //     snapEnd();
    // }

    // function testERC721SetAllowanceDeadlinePassed() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 sigDeadline = block.timestamp + 100;

    //     vm.warp(block.timestamp + 101);
    //     snapStart("permitSignatureExpired");
    //     vm.expectRevert(abi.encodeWithSelector(SignatureExpired.selector, sigDeadline));
    //     permit2.permit(from, permit, sig);
    //     snapEnd();
    // }

    // function testERC721MaxAllowance() public {
    //     uint160 maxAllowance = type(uint160).max;
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), maxAllowance, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     snapStart("permitSetMaxAllowanceCleanWrite");
    //     permit2.permit(from, permit, sig);
    //     snapEnd();

    //     (uint160 startAllowedAmount0,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(startAllowedAmount0, type(uint160).max);

    //     permit2.transferFrom(from, address0, defaultTokenId, address(nft1));

    //     (uint160 endAllowedAmount0,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(endAllowedAmount0, type(uint160).max);

    //     assertEq(token0.balanceOf(from), startBalanceFrom - defaultTokenId);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + defaultTokenId);
    // }

    // function testERC721MaxAllowanceDirtyWrite() public {
    //     uint160 maxAllowance = type(uint160).max;
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), maxAllowance, defaultExpiration, dirtyNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(fromDirty);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     snapStart("permitSetMaxAllowanceDirtyWrite");
    //     permit2.permit(fromDirty, permit, sig);
    //     snapEnd();

    //     (uint160 startAllowedAmount0,,) = permit2.allowance(fromDirty, address(nft1), address(this));
    //     assertEq(startAllowedAmount0, type(uint160).max);

    //     permit2.transferFrom(fromDirty, address0, defaultTokenId, address(nft1));

    //     (uint160 endAllowedAmount0,,) = permit2.allowance(fromDirty, address(nft1), address(this));
    //     assertEq(endAllowedAmount0, type(uint160).max);

    //     assertEq(token0.balanceOf(fromDirty), startBalanceFrom - defaultTokenId);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + defaultTokenId);
    // }

    // function testERC721PartialAllowance() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 startAllowedAmount0,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(startAllowedAmount0, defaultTokenId);

    //     uint160 transferAmount = 5 ** 18;
    //     permit2.transferFrom(from, address0, transferAmount, address(nft1));
    //     (uint160 endAllowedAmount0,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     // ensure the allowance was deducted
    //     assertEq(endAllowedAmount0, defaultTokenId - transferAmount);

    //     assertEq(token0.balanceOf(from), startBalanceFrom - transferAmount);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + transferAmount);
    // }

    // function testERC721ReuseOrderedNonceInvalid() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     permit2.permit(from, permit, sig);
    //     (,, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(nonce, 1);

    //     (uint160 amount, uint48 expiration,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));
    //     assertEq(expiration, defaultExpiration);

    //     vm.expectRevert(InvalidNonce.selector);
    //     permit2.permit(from, permit, sig);
    // }

    // function testERC721InvalidateNonces() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     // Invalidates the 0th nonce by setting the new nonce to 1.
    //     vm.prank(from);
    //     vm.expectEmit(true, true, true, true);
    //     emit NonceInvalidation(from, address(nft1), address(this), 1, defaultNonce);
    //     permit2.invalidateNonces(address(nft1), address(this), 1);
    //     (,, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(nonce, 1);

    //     vm.expectRevert(InvalidNonce.selector);
    //     permit2.permit(from, permit, sig);
    // }

    // function testERC721InvalidateMultipleNonces() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     // Valid permit, uses nonce 0.
    //     permit2.permit(from, permit, sig);
    //     (,, uint48 nonce1) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(nonce1, 1);

    //     permit = defaultERC721PermitAllowance(address(token1), defaultTokenId, defaultExpiration, nonce1);
    //     sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     // Invalidates the 9 nonces by setting the new nonce to 33.
    //     vm.prank(from);
    //     vm.expectEmit(true, true, true, true);

    //     emit NonceInvalidation(from, address(nft1), address(this), 33, nonce1);
    //     permit2.invalidateNonces(address(nft1), address(this), 33);
    //     (,, uint48 nonce2) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(nonce2, 33);

    //     vm.expectRevert(InvalidNonce.selector);
    //     permit2.permit(from, permit, sig);
    // }

    // function testERC721InvalidateNoncesInvalid() public {
    //     // fromDirty nonce is 1
    //     vm.prank(fromDirty);
    //     vm.expectRevert(InvalidNonce.selector);
    //     // setting nonce to 0 should revert
    //     permit2.invalidateNonces(address(nft1), address(this), 0);
    // }

    // function testERC721ExcessiveInvalidation() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint32 numInvalidate = type(uint16).max;
    //     vm.startPrank(from);
    //     vm.expectRevert(IAllowanceTransferERC721.ExcessiveInvalidation.selector);
    //     permit2.invalidateNonces(address(nft1), address(this), numInvalidate + 1);
    //     vm.stopPrank();

    //     permit2.permit(from, permit, sig);
    //     (,, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(nonce, 1);
    // }

    // function testERC721BatchTransferFrom() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address0);

    //     permit2.permit(from, permit, sig);

    //     (uint160 amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));

    //     // permit token0 for 1 ** 18
    //     address[] memory owners = AddressBuilder.fill(3, from);
    //     IAllowanceTransferERC721.AllowanceTransferDetails[] memory transferDetails =
    //         StructBuilder.fillAllowanceTransferDetail(3, address(nft1), 1 ** 18, address0, owners);
    //     snapStart("batchTransferFrom");
    //     permit2.transferFrom(transferDetails);
    //     snapEnd();
    //     assertEq(token0.balanceOf(from), startBalanceFrom - 3 * 1 ** 18);
    //     assertEq(token0.balanceOf(address0), startBalanceTo + 3 * 1 ** 18);
    //     (amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(amount, defaultTokenId - 3 * 1 ** 18);
    // }

    // function testERC721BatchTransferFromMultiToken() public {
    //     address[] memory tokens = AddressBuilder.fill(1, address(nft1)).push(address(token1));
    //     IAllowanceTransferERC721.PermitBatch memory permitBatch =
    //         defaultERC20PermitBatchAllowance(tokens, defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permitBatch, fromPrivateKey, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom0 = token0.balanceOf(from);
    //     uint256 startBalanceFrom1 = token1.balanceOf(from);
    //     uint256 startBalanceTo0 = token0.balanceOf(address0);
    //     uint256 startBalanceTo1 = token1.balanceOf(address0);

    //     permit2.permit(from, permitBatch, sig);

    //     (uint160 amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));
    //     (amount,,) = permit2.allowance(from, address(token1), address(this));
    //     assertEq(spender, address(this));

    //     // permit token0 for 1 ** 18
    //     address[] memory owners = AddressBuilder.fill(2, from);
    //     IAllowanceTransferERC721.AllowanceTransferDetails[] memory transferDetails =
    //         StructBuilder.fillAllowanceTransferDetail(2, tokens, 1 ** 18, address0, owners);
    //     snapStart("batchTransferFromMultiToken");
    //     permit2.transferFrom(transferDetails);
    //     snapEnd();
    //     assertEq(token0.balanceOf(from), startBalanceFrom0 - 1 ** 18);
    //     assertEq(token1.balanceOf(from), startBalanceFrom1 - 1 ** 18);
    //     assertEq(token0.balanceOf(address0), startBalanceTo0 + 1 ** 18);
    //     assertEq(token1.balanceOf(address0), startBalanceTo1 + 1 ** 18);
    //     (amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(amount, defaultTokenId - 1 ** 18);
    //     (amount,,) = permit2.allowance(from, address(token1), address(this));
    //     assertEq(amount, defaultTokenId - 1 ** 18);
    // }

    // function testERC721BatchTransferFromDifferentOwners() public {
    //     IAllowanceTransferERC721.PermitSingle memory permit =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     IAllowanceTransferERC721.PermitSingle memory permitDirty =
    //         defaultERC721PermitAllowance(address(nft1), defaultTokenId, defaultExpiration, dirtyNonce);
    //     bytes memory sigDirty = getPermitSignature(permitDirty, fromPrivateKeyDirty, DOMAIN_SEPARATOR);

    //     uint256 startBalanceFrom = token0.balanceOf(from);
    //     uint256 startBalanceTo = token0.balanceOf(address(this));
    //     uint256 startBalanceFromDirty = token0.balanceOf(fromDirty);

    //     // from and fromDirty approve address(this) as spender
    //     permit2.permit(from, permit, sig);
    //     permit2.permit(fromDirty, permitDirty, sigDirty);

    //     (uint160 amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));
    //     (uint160 amount1,,) = permit2.allowance(fromDirty, address(nft1), address(this));
    //     assertEq(amount1, defaultTokenId);

    //     address[] memory owners = AddressBuilder.fill(1, from).push(fromDirty);
    //     IAllowanceTransferERC721.AllowanceTransferDetails[] memory transferDetails =
    //         StructBuilder.fillAllowanceTransferDetail(2, address(nft1), 1 ** 18, address(this), owners);
    //     snapStart("transferFrom with different owners");
    //     permit2.transferFrom(transferDetails);
    //     snapEnd();

    //     assertEq(token0.balanceOf(from), startBalanceFrom - 1 ** 18);
    //     assertEq(token0.balanceOf(fromDirty), startBalanceFromDirty - 1 ** 18);
    //     assertEq(token0.balanceOf(address(this)), startBalanceTo + 2 * 1 ** 18);
    //     (amount,,) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(amount, defaultTokenId - 1 ** 18);
    //     (amount,,) = permit2.allowance(fromDirty, address(nft1), address(this));
    //     assertEq(amount, defaultTokenId - 1 ** 18);
    // }

    // function testERC721Lockdown() public {
    //     address[] memory tokens = AddressBuilder.fill(1, address(nft1)).push(address(token1));
    //     IAllowanceTransferERC721.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     permit2.permit(from, permit, sig);

    //     (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, address(token1), address(this));
    //     assertEq(amount1, defaultTokenId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);

    //     IAllowanceTransferERC721.TokenSpenderPair[] memory approvals =
    //         new IAllowanceTransferERC721.TokenSpenderPair[](2);
    //     approvals[0] = IAllowanceTransferERC721.TokenSpenderPair(address(nft1), address(this));
    //     approvals[1] = IAllowanceTransferERC721.TokenSpenderPair(address(token1), address(this));

    //     vm.prank(from);
    //     snapStart("lockdown");
    //     permit2.lockdown(approvals);
    //     snapEnd();

    //     (amount, expiration, nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(amount, 0);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (amount1, expiration1, nonce1) = permit2.allowance(from, address(token1), address(this));
    //     assertEq(amount1, 0);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }

    // function testERC721LockdownEvent() public {
    //     address[] memory tokens = AddressBuilder.fill(1, address(nft1)).push(address(token1));
    //     IAllowanceTransferERC721.PermitBatch memory permit =
    //         defaultERC20PermitBatchAllowance(tokens, defaultTokenId, defaultExpiration, defaultNonce);
    //     bytes memory sig = getPermitBatchSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

    //     permit2.permit(from, permit, sig);

    //     (address spender, uint48 expiration, uint48 nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(spender, address(this));
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (uint160 amount1, uint48 expiration1, uint48 nonce1) = permit2.allowance(from, address(token1), address(this));
    //     assertEq(amount1, defaultTokenId);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);

    //     IAllowanceTransferERC721.TokenSpenderPair[] memory approvals =
    //         new IAllowanceTransferERC721.TokenSpenderPair[](2);
    //     approvals[0] = IAllowanceTransferERC721.TokenSpenderPair(address(nft1), address(this));
    //     approvals[1] = IAllowanceTransferERC721.TokenSpenderPair(address(token1), address(this));

    //     //TODO :fix expecting multiple events, can only check for 1
    //     vm.prank(from);
    //     vm.expectEmit(true, false, false, false);
    //     emit Lockdown(from, address(nft1), address(this));
    //     permit2.lockdown(approvals);

    //     (amount, expiration, nonce) = permit2.allowance(from, address(nft1), defaultTokenId);
    //     assertEq(amount, 0);
    //     assertEq(expiration, defaultExpiration);
    //     assertEq(nonce, 1);
    //     (amount1, expiration1, nonce1) = permit2.allowance(from, address(token1), address(this));
    //     assertEq(amount1, 0);
    //     assertEq(expiration1, defaultExpiration);
    //     assertEq(nonce1, 1);
    // }
}
