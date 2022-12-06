// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MainnetTokenTest} from "../MainnetToken.t.sol";

contract FeeOnTransferTokenTest is MainnetTokenTest {
    function token() internal pure override returns (ERC20) {
        return ERC20(0xF5238462E7235c7B62811567E63Dd17d12C2EAA0);
    }
}
