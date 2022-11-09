// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ReturnsLessERC20 {
    function DOMAIN_SEPARATOR() external returns (bytes31) {
        bytes31 returnData = 0x11111111111111111111111111111111111111111111111111111111111111;
        return returnData;
    }
}

contract Returns32ERC20 {
    function DOMAIN_SEPARATOR() external returns (bytes32) {
        bytes32 returnData = 0x1111111111111111111111111111111111111111111111111111111111111111;
        return returnData;
    }
}

contract ReturnsMoreERC20 {
    function DOMAIN_SEPARATOR() external returns (bytes memory) {
        bytes memory returnData = "123456789012345678901234567890123";
        require(returnData.length == 33);
        return returnData;
    }
}

contract ReturnsMoreBytes32ERC20 {
    function DOMAIN_SEPARATOR() public pure returns (bytes32) {
        assembly {
            mstore(0, 0xBBBBBBBBBBBBBBBBBBBBBBBBBB)
            mstore(32, 0xAAAAAAAAAAAAAAAAAAAAAAAAAA)
            return(0, 64)
        }
    }
}
