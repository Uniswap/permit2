// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MainnetTokenTest} from "../MainnetToken.t.sol";

contract USDCTest is MainnetTokenTest {
    function token() internal pure override returns (ERC20) {
        return ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    }
}
