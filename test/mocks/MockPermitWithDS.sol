// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract MockPermitWithSmallDS is MockERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) MockERC20(_name, _symbol, _decimals) {}

    function DOMAIN_SEPARATOR() public pure override returns (bytes32) {
        bytes31 returnData = 0x11111111111111111111111111111111111111111111111111111111111111;
        return returnData;
    }
}

contract MockPermitWithLargerDS is MockERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) MockERC20(_name, _symbol, _decimals) {}

    function DOMAIN_SEPARATOR() public pure override returns (bytes32) {
        assembly {
            mstore(0, 0xBBBBBBBBBBBBBBBBBBBBBBBBBB)
            mstore(32, 0xAAAAAAAAAAAAAAAAAAAAAAAAAA)
            return(0, 64)
        }
    }
}
