// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Approve2} from "../src/Approve2.sol";
import {Approve2Lib} from "../src/Approve2Lib.sol";

contract Approve2Test is DSTestPlus, Approve2Lib {
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 immutable DOMAIN_SEPARATOR;

    Approve2 immutable approve2 = new Approve2();

    MockERC20 immutable token = new MockERC20("Mock Token", "MOCK", 18);

    constructor() Approve2Lib(approve2) {
        DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();

        token.mint(address(this), type(uint128).max);

        token.approve(address(this), type(uint128).max);
    }

    /*//////////////////////////////////////////////////////////////
                        BASIC PERMIT2 BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testStandardPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testOZSafePermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        SafeERC20.safePermit(IERC20Permit(address(token)), owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testPermit2() public {
        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        permit2(token, owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                     BASIC TRANSFERFROM2 BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testStandardTransferFrom() public {
        token.transferFrom(address(this), address(0xBEEF), 1e18);
    }

    function testOZSafeTransferFrom() public {
        SafeERC20.safeTransferFrom(IERC20(address(token)), address(this), address(0xBEEF), 1e18);
    }

    function testTransferFrom2() public {
        transferFrom2(token, address(this), address(0xBEEF), 1e18);
    }
}
