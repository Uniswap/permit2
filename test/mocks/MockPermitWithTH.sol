// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract MockPermitWithSmallTH is MockERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) MockERC20(_name, _symbol, _decimals) {}

    function DOMAIN_SEPARATOR() public pure override returns (bytes32) {
        bytes31 returnData = 0x11111111111111111111111111111111111111111111111111111111111111;
        return returnData;
    }

    function PERMIT_TYPEHASH() public pure returns (bytes32) {
        return keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    }
}

contract MockPermitWithLargerTH is MockERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) MockERC20(_name, _symbol, _decimals) {}

    function DOMAIN_SEPARATOR() public pure override returns (bytes32) {
        assembly {
            mstore(0, 0xBBBBBBBBBBBBBBBBBBBBBBBBBB)
            mstore(32, 0xAAAAAAAAAAAAAAAAAAAAAAAAAA)
            return(0, 64)
        }
    }

    function PERMIT_TYPEHASH() public pure returns (bytes32) {
        assembly {
            mstore(0, 0xBBBBBBBBBBBBBBBBBBBBBBBBBB)
            mstore(32, 0xAAAAAAAAAAAAAAAAAAAAAAAAAA)
            return(0, 64)
        }
    }
}
