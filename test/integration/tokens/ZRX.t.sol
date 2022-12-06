// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MainnetTokenTest} from "../MainnetToken.t.sol";

contract ZRXTest is MainnetTokenTest {
    function token() internal pure override returns (ERC20) {
        return ERC20(0xE41d2489571d322189246DaFA5ebDe1F4699F498);
    }
}
