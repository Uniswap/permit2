// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "../../src/interfaces/ISignatureTransfer.sol";
import {TokenProvider} from "./TokenProvider.sol";
import {PermitSignature} from "./PermitSignature.sol";
import {DeployPermit2} from "./DeployPermit2.sol";
import {Permit2} from "../../src/Permit2.sol";

contract DeployPermit2Test is Test, DeployPermit2, PermitSignature, TokenProvider {
    Permit2 permit2;
    address from;
    uint256 fromPrivateKey;

    address address0 = address(0);
    address address1 = address(2);

    uint160 defaultAmount = 10 ** 18;
    uint48 defaultNonce = 0;
    uint32 dirtyNonce = 1;
    uint48 defaultExpiration = uint48(block.timestamp + 5);

    bytes32 DOMAIN_SEPARATOR;

    function setUp() public {
        permit2 = Permit2(deployPermit2());
        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(permit2));
    }

    function testDeployPermit2() public {
        Permit2 realPermit2 = new Permit2();
        // assert bytecode equals
        assertEq(address(permit2).code, address(realPermit2).code);
    }

    function testAllowanceTransferSanityCheck() public {
        IAllowanceTransfer.PermitSingle memory permit =
            defaultERC20PermitAllowance(address(token0), defaultAmount, defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address0);

        permit2.permit(from, permit, sig);

        (uint160 amount,,) = permit2.allowance(from, address(token0), address(this));

        assertEq(amount, defaultAmount);

        permit2.transferFrom(from, address0, defaultAmount, address(token0));

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address0), startBalanceTo + defaultAmount);
    }

    function testSignatureTransferSanityCheck() public {
        uint256 nonce = 0;
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(address(token0), nonce);
        bytes memory sig = getPermitTransferSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address1);

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: address1, requestedAmount: defaultAmount});

        permit2.permitTransferFrom(permit, transferDetails, from, sig);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address1), startBalanceTo + defaultAmount);
    }
}
