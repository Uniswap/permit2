// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MockNonPermitNonERC20WithDS {
    function DOMAIN_SEPARATOR() external pure returns (bytes memory) {
        bytes memory returnData = "123456789012345678901234567890123";
        require(returnData.length == 33);
        return returnData;
    }
}
