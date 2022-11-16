// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MainnetTokenTest} from "../MainnetToken.t.sol";

contract USDTTest is MainnetTokenTest {
    using SafeTransferLib for ERC20;

    function token() internal pure override returns (ERC20) {
        return ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    }
}
