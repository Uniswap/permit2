// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {Permit2} from "../src/Permit2.sol";
import {Permit2Lib} from "../src/libraries/Permit2Lib.sol";
import {MockNonPermitERC20} from "./mocks/MockNonPermitERC20.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";

contract Permit2LibTest is Test, PermitSignature, GasSnapshot {
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 immutable TOKEN_DOMAIN_SEPARATOR;
    bytes32 immutable PERMIT2_DOMAIN_SEPARATOR;

    uint256 immutable PK;
    address immutable PK_OWNER;

    Permit2 immutable permit2 = new Permit2();

    MockERC20 immutable token = new MockERC20("Mock Token", "MOCK", 18);

    MockNonPermitERC20 immutable nonPermitToken = new MockNonPermitERC20("Mock NonPermit Token", "MOCK", 18);

    constructor() {
        PK = 0xBEEF;
        PK_OWNER = vm.addr(PK);

        TOKEN_DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        PERMIT2_DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        token.mint(address(this), type(uint128).max);
        token.approve(address(this), type(uint128).max);
        token.approve(address(permit2), type(uint128).max);

        token.mint(PK_OWNER, type(uint128).max);
        vm.prank(PK_OWNER);
        token.approve(address(permit2), type(uint128).max);

        nonPermitToken.mint(address(this), type(uint128).max);
        nonPermitToken.approve(address(this), type(uint128).max);
        nonPermitToken.approve(address(permit2), type(uint128).max);

        nonPermitToken.mint(PK_OWNER, type(uint128).max);
        vm.prank(PK_OWNER);
        nonPermitToken.approve(address(permit2), type(uint128).max);
    }

    function setUp() public {
        testPermit2Full();
        testPermit2NonPermitToken();
        testStandardPermit();
    }

    /*//////////////////////////////////////////////////////////////
                        BASIC PERMIT2 BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testStandardPermit() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    TOKEN_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
    }

    function testOZSafePermit() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    TOKEN_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
                        )
                    )
                )
            )
        );

        SafeERC20.safePermit(IERC20Permit(address(token)), PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
    }

    function testPermit2() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    TOKEN_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
                        )
                    )
                )
            )
        );

        Permit2Lib.permit2(token, PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
    }

    function testPermit2InvalidAmount() public {
        (,, uint32 nonce) = permit2.allowance(PK_OWNER, address(nonPermitToken), address(0xCAFE));

        IAllowanceTransfer.Permit memory permit = IAllowanceTransfer.Permit({
            token: address(nonPermitToken),
            spender: address(0xCAFE),
            amount: type(uint160).max,
            expiration: type(uint64).max,
            nonce: nonce,
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);
        vm.expectRevert(bytes("SafeCast: value doesn't fit in 160 bits"));
        Permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 2 ** 170, block.timestamp, v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                     BASIC TRANSFERFROM2 BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testStandardTransferFrom() public {
        token.transferFrom(address(this), address(0xBEEF), 1e18);
    }

    function testOZSafeTransferFrom() public {
        SafeERC20.safeTransferFrom(IERC20(address(token)), address(this), address(0xB00B), 1e18);
    }

    function testTransferFrom2() public {
        Permit2Lib.transferFrom2(token, address(this), address(0xB00B), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                       ADVANCED PERMIT2 BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testPermit2Full() public {
        (,, uint32 nonce) = permit2.allowance(PK_OWNER, address(token), address(0xCAFE));

        IAllowanceTransfer.Permit memory permit = IAllowanceTransfer.Permit({
            token: address(token),
            spender: address(0xCAFE),
            amount: 1e18,
            expiration: type(uint64).max,
            nonce: nonce,
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        Permit2Lib.permit2(token, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testPermit2NonPermitToken() public {
        (,, uint32 nonce) = permit2.allowance(PK_OWNER, address(nonPermitToken), address(0xCAFE));

        IAllowanceTransfer.Permit memory permit = IAllowanceTransfer.Permit({
            token: address(nonPermitToken),
            spender: address(0xCAFE),
            amount: 1e18,
            expiration: type(uint64).max,
            nonce: nonce,
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        Permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                    ADVANCED TRANSFERFROM BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testTransferFrom2Full() public {
        vm.startPrank(address(0xCAFE));

        Permit2Lib.transferFrom2(token, PK_OWNER, address(0xB00B), 1e18);
    }

    function testTransferFrom2NonPermitToken() public {
        vm.startPrank(address(0xCAFE));

        Permit2Lib.transferFrom2(nonPermitToken, PK_OWNER, address(0xB00B), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                          END TO END BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testOZSafePermitPlusOZSafeTransferFrom() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    TOKEN_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
                        )
                    )
                )
            )
        );

        vm.startPrank(address(0xB00B));

        snapStart("safePermit + safeTransferFrom with an EIP-2612 native token");

        SafeERC20.safePermit(IERC20Permit(address(token)), PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
        SafeERC20.safeTransferFrom(IERC20(address(token)), PK_OWNER, address(0xB00B), 1e18);

        snapEnd();
    }

    function testPermit2PlusTransferFrom2() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    TOKEN_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
                        )
                    )
                )
            )
        );

        vm.startPrank(address(0xB00B));

        snapStart("permit2 + transferFrom2 with an EIP-2612 native token");

        Permit2Lib.permit2(token, PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
        Permit2Lib.transferFrom2(token, PK_OWNER, address(0xB00B), 1e18);

        snapEnd();
    }

    function testPermit2PlusTransferFrom2WithNonPermit() public {
        (,, uint32 nonce) = permit2.allowance(PK_OWNER, address(nonPermitToken), address(0xCAFE));

        IAllowanceTransfer.Permit memory permit = IAllowanceTransfer.Permit({
            token: address(nonPermitToken),
            spender: address(0xCAFE),
            amount: 1e18,
            expiration: type(uint64).max,
            nonce: nonce,
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        vm.startPrank(address(0xCAFE));

        snapStart("permit2 + transferFrom2 with a non EIP-2612 native token");

        Permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        Permit2Lib.transferFrom2(nonPermitToken, PK_OWNER, address(0xB00B), 1e18);

        snapEnd();
    }
}
