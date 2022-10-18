// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Permit2} from "../src/Permit2.sol";
import {Permit2Lib} from "../src/libraries/Permit2Lib.sol";
import {MockNonPermitERC20} from "./mocks/MockNonPermitERC20.sol";

contract Permit2Test is DSTestPlus {
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 immutable DOMAIN_SEPARATOR;

    bytes32 immutable DOMAIN_SEPARATOR_TOKEN;
    bytes32 immutable DOMAIN_SEPARATOR_NON_PERMIT_TOKEN;

    uint256 immutable PK;
    address immutable PK_OWNER;

    Permit2 immutable permit2 = new Permit2();

    MockERC20 immutable token = new MockERC20("Mock Token", "MOCK", 18);

    MockNonPermitERC20 immutable nonPermitToken = new MockNonPermitERC20("Mock NonPermit Token", "MOCK", 18);

    constructor() {
        PK = 0xBEEF;
        PK_OWNER = hevm.addr(PK);

        DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();

        DOMAIN_SEPARATOR_TOKEN = permit2.DOMAIN_SEPARATOR();
        DOMAIN_SEPARATOR_NON_PERMIT_TOKEN = permit2.DOMAIN_SEPARATOR();

        token.mint(address(this), type(uint128).max);
        token.approve(address(this), type(uint128).max);
        token.approve(address(permit2), type(uint128).max);

        token.mint(PK_OWNER, type(uint128).max);
        hevm.prank(PK_OWNER);
        token.approve(address(permit2), type(uint128).max);

        nonPermitToken.mint(address(this), type(uint128).max);
        nonPermitToken.approve(address(this), type(uint128).max);
        nonPermitToken.approve(address(permit2), type(uint128).max);

        nonPermitToken.mint(PK_OWNER, type(uint128).max);
        hevm.prank(PK_OWNER);
        nonPermitToken.approve(address(permit2), type(uint128).max);
    }

    function setUp() public {
        // testPermit2Full();
        // testPermit2NonPermitToken();
        // testStandardPermit();
    }

    /*//////////////////////////////////////////////////////////////
                        BASIC PERMIT2 BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testStandardPermit() public {
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
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
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
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

    // function testPermit2() public {
    //     (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
    //         PK,
    //         keccak256(
    //             abi.encodePacked(
    //                 "\x19\x01",
    //                 DOMAIN_SEPARATOR,
    //                 keccak256(
    //                     abi.encode(
    //                         PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
    //                     )
    //                 )
    //             )
    //         )
    //     );

    //     Permit2Lib.permit2(token, PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
    // }

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

    // function testPermit2Full() public {
    //     (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
    //         PK,
    //         keccak256(
    //             abi.encodePacked(
    //                 "\x19\x01",
    //                 DOMAIN_SEPARATOR_TOKEN,
    //                 keccak256(
    //                     abi.encode(
    //                         PERMIT_TYPEHASH, PK_OWNER, address(0xCAFE), 1e18, permit2.nonces(PK_OWNER), block.timestamp
    //                     )
    //                 )
    //             )
    //         )
    //     );

    //     Permit2Lib.permit2(token, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    // }

    // function testPermit2NonPermitToken() public {
    //     (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
    //         PK,
    //         keccak256(
    //             abi.encodePacked(
    //                 "\x19\x01",
    //                 DOMAIN_SEPARATOR_NON_PERMIT_TOKEN,
    //                 keccak256(
    //                     abi.encode(
    //                         PERMIT_TYPEHASH, PK_OWNER, address(0xCAFE), 1e18, permit2.nonces(PK_OWNER), block.timestamp
    //                     )
    //                 )
    //             )
    //         )
    //     );

    //     Permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    // }

    /*//////////////////////////////////////////////////////////////
                    ADVANCED TRANSFERFROM BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    //TODO the Lib needs to pass in correct vars to transfer from
    // function testTransferFrom2Full() public {
    //     hevm.startPrank(address(0xCAFE));

    //     Permit2Lib.transferFrom2(token, PK_OWNER, address(0xB00B), 1e18);
    // }

    // function testTransferFrom2NonPermitToken() public {
    //     hevm.startPrank(address(0xCAFE));

    //     Permit2Lib.transferFrom2(nonPermitToken, PK_OWNER, address(0xB00B), 1e18);
    // }

    /*//////////////////////////////////////////////////////////////
                          END TO END BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testOZSafePermitPlusOZSafeTransferFrom() public {
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
                        )
                    )
                )
            )
        );

        hevm.startPrank(address(0xB00B));

        startMeasuringGas("safePermit + safeTransferFrom with an EIP-2612 native token");

        SafeERC20.safePermit(IERC20Permit(address(token)), PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
        SafeERC20.safeTransferFrom(IERC20(address(token)), PK_OWNER, address(0xB00B), 1e18);

        stopMeasuringGas();
    }

    // function testPermit2PlusTransferFrom2() public {
    //     (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
    //         PK,
    //         keccak256(
    //             abi.encodePacked(
    //                 "\x19\x01",
    //                 DOMAIN_SEPARATOR,
    //                 keccak256(
    //                     abi.encode(
    //                         PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
    //                     )
    //                 )
    //             )
    //         )
    //     );

    //     hevm.startPrank(address(0xB00B));

    //     startMeasuringGas("permit2 + transferFrom2 with an EIP-2612 native token");

    //     Permit2Lib.permit2(token, PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
    //     Permit2Lib.transferFrom2(token, PK_OWNER, address(0xB00B), 1e18);

    //     stopMeasuringGas();
    // }

    // function testPermit2PlusTransferFrom2WithNonPermit() public {
    //     (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
    //         PK,
    //         keccak256(
    //             abi.encodePacked(
    //                 "\x19\x01",
    //                 DOMAIN_SEPARATOR_NON_PERMIT_TOKEN,
    //                 keccak256(
    //                     abi.encode(
    //                         PERMIT_TYPEHASH, PK_OWNER, address(0xCAFE), 1e18, permit2.nonces(PK_OWNER), block.timestamp
    //                     )
    //                 )
    //             )
    //         )
    //     );

    //     hevm.startPrank(address(0xCAFE));

    //     startMeasuringGas("permit2 + transferFrom2 with a non EIP-2612 native token");

    //     Permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    //     Permit2Lib.transferFrom2(nonPermitToken, PK_OWNER, address(0xB00B), 1e18);

    //     stopMeasuringGas();
    // }
}
