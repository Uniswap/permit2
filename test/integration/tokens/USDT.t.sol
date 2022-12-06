// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MainnetTokenTest} from "../MainnetToken.t.sol";

contract USDTTest is MainnetTokenTest {
    using SafeTransferLib for ERC20;

    function token() internal pure override returns (ERC20) {
        return ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    }
}
