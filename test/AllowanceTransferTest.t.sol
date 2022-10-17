pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

contract AllowanceTransferTest is Test, TokenProvider, GasSnapshot {
    Permit2 permit2;
    address from;
    uint256 fromPrivateKey;

    function setUp() public {
        permit2 = new Permit2();
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        setTestTokens(from);
        setTestTokenApprovals(vm, from, address(permit2));
    }

    function testAllowancePermit() public {}
}
