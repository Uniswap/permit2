// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MainnetTokenTest} from "../MainnetToken.t.sol";

contract WBTCTest is MainnetTokenTest {
    function token() internal pure override returns (ERC20) {
        return ERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    }
}
