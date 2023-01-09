// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {BaseAllowanceTransferTest} from "./BaseAllowanceTransferTest.t.sol";
import {Permit2} from "../src/ERC20/Permit2.sol";

contract AllowanceTransferTest_ERC20 is BaseAllowanceTransferTest {
    function setUp() public override {
        // setUp overridden in ERC specific testsg
        permit2 = new Permit2();
        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        // amount for ERC20s
        defaultAmountOrId = 10 ** 18;

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
        vm.startPrank(fromDirty);
        permit2.invalidateNonces(address(token0), address(this), 1);
        permit2.invalidateNonces(address(token1), address(this), 1);
        vm.stopPrank();
        // ensure address3 has some balance of token0 and token1 for dirty sstore on transfer
        token0.mint(address3, defaultAmountOrId);
        token1.mint(address3, defaultAmountOrId);
    }
}
