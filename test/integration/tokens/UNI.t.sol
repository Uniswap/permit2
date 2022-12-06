// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MainnetTokenTest} from "../MainnetToken.t.sol";

contract UNITest is MainnetTokenTest {
    function token() internal pure override returns (ERC20) {
        return ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    }
}
