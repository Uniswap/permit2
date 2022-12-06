// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MainnetTokenTest} from "../MainnetToken.t.sol";

contract RebasingTokenTest is MainnetTokenTest {
    function token() internal pure override returns (ERC20) {
        return ERC20(0xD46bA6D942050d489DBd938a2C909A5d5039A161);
    }

    function dealTokens(address to, uint256 amount) internal override {
        // large holder
        vm.prank(0xc3a947372191453Dd9dB02B0852d378dCCBDf271);
        token().transfer(to, amount);
    }
}
