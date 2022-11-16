pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit2} from "../../src/Permit2.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract Spender is Test {
    Permit2 private immutable permit2;
    MockERC20 private immutable token;

    uint256 public amountSpent;

    constructor(Permit2 _permit2, MockERC20 _token) {
        permit2 = _permit2;
        token = _token;
    }

    function spendPermit(uint160 amount, address from) public {
        permit2.transferFrom(from, address(this), amount, address(token));
        amountSpent += amount;
    }
}
