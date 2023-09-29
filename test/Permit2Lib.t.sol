// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {DSTestPlus} from "solmate/src/test/utils/DSTestPlus.sol";
import {MockERC20, ERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Permit2} from "../src/Permit2.sol";
import {Permit2Lib} from "../src/libraries/Permit2Lib.sol";
import {MockNonPermitERC20} from "./mocks/MockNonPermitERC20.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {MockPermit2Lib} from "./mocks/MockPermit2Lib.sol";
import {SafeCast160} from "../src/libraries/SafeCast160.sol";
import {MockPermitWithSmallDS, MockPermitWithLargerDS} from "./mocks/MockPermitWithDS.sol";
import {MockNonPermitNonERC20WithDS} from "./mocks/MockNonPermitNonERC20WithDS.sol";
import {SignatureVerification} from "../src/libraries/SignatureVerification.sol";
import {MockFallbackERC20} from "./mocks/MockFallbackERC20.sol";

contract Permit2LibTest is Test, PermitSignature, GasSnapshot {
    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 immutable TOKEN_DOMAIN_SEPARATOR;
    bytes32 immutable PERMIT2_DOMAIN_SEPARATOR;
    bytes32 immutable TEST_SML_DS_DOMAIN_SEPARATOR;
    bytes32 immutable TEST_LG_DS_DOMAIN_SEPARATOR;

    uint256 immutable PK;
    address immutable PK_OWNER;

    Permit2 immutable permit2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    ERC20 immutable weth9Mainnet = ERC20(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));

    // Use to test errors in Permit2Lib calls.
    MockPermit2Lib immutable permit2Lib = new MockPermit2Lib();

    MockERC20 immutable token = new MockERC20("Mock Token", "MOCK", 18);

    MockNonPermitERC20 immutable nonPermitToken = new MockNonPermitERC20("Mock NonPermit Token", "MOCK", 18);
    MockFallbackERC20 immutable fallbackToken = new MockFallbackERC20("Mock Fallback Token", "MOCK", 18);
    MockPermitWithSmallDS immutable lessDSToken =
        new MockPermitWithSmallDS("Mock Permit Token Small Domain Sep", "MOCK", 18);
    MockPermitWithLargerDS immutable largerDSToken =
        new MockPermitWithLargerDS("Mock Permit Token Larger Domain Sep", "MOCK", 18);
    MockNonPermitNonERC20WithDS immutable largerNonStandardDSToken = new MockNonPermitNonERC20WithDS();

    constructor() {
        PK = 0xBEEF;
        PK_OWNER = vm.addr(PK);
        Permit2 tempPermit2 = new Permit2();
        vm.etch(address(permit2), address(tempPermit2).code);
        vm.etch(address(weth9Mainnet), address(nonPermitToken).code);

        TOKEN_DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        PERMIT2_DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
        TEST_SML_DS_DOMAIN_SEPARATOR = lessDSToken.DOMAIN_SEPARATOR();
        TEST_LG_DS_DOMAIN_SEPARATOR = largerDSToken.DOMAIN_SEPARATOR();

        token.mint(address(this), type(uint128).max);
        token.approve(address(this), type(uint128).max);
        token.approve(address(permit2), type(uint128).max);

        lessDSToken.mint(address(this), type(uint128).max);
        lessDSToken.approve(address(this), type(uint128).max);
        lessDSToken.approve(address(permit2), type(uint128).max);

        lessDSToken.mint(PK_OWNER, type(uint128).max);
        vm.prank(PK_OWNER);
        lessDSToken.approve(address(permit2), type(uint128).max);

        token.mint(PK_OWNER, type(uint128).max);
        vm.prank(PK_OWNER);
        token.approve(address(permit2), type(uint128).max);

        nonPermitToken.mint(address(this), type(uint128).max);
        nonPermitToken.approve(address(this), type(uint128).max);
        nonPermitToken.approve(address(permit2), type(uint128).max);

        nonPermitToken.mint(PK_OWNER, type(uint128).max);
        vm.prank(PK_OWNER);
        nonPermitToken.approve(address(permit2), type(uint128).max);

        MockNonPermitERC20(address(weth9Mainnet)).mint(address(this), type(uint128).max);
        weth9Mainnet.approve(address(this), type(uint128).max);
        weth9Mainnet.approve(address(permit2), type(uint128).max);

        MockNonPermitERC20(address(weth9Mainnet)).mint(PK_OWNER, type(uint128).max);
        vm.prank(PK_OWNER);
        weth9Mainnet.approve(address(permit2), type(uint128).max);

        fallbackToken.mint(address(this), type(uint128).max);
        fallbackToken.approve(address(this), type(uint128).max);
        fallbackToken.approve(address(permit2), type(uint128).max);

        fallbackToken.mint(PK_OWNER, type(uint128).max);
        vm.prank(PK_OWNER);
        fallbackToken.approve(address(permit2), type(uint128).max);
    }

    function setUp() public {
        testPermit2Full();
        testPermit2NonPermitFallback();
        testPermit2NonPermitToken();
        testPermit2WETH9Mainnet();
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
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(nonPermitToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(nonPermitToken),
                amount: type(uint160).max,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);
        vm.expectRevert(SafeCast160.UnsafeCast.selector);
        permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 2 ** 170, block.timestamp, v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                        BASIC SIMPLE PERMIT2 BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testSimplePermit2InvalidAmount() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(nonPermitToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(nonPermitToken),
                amount: type(uint160).max,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);
        vm.expectRevert(SafeCast160.UnsafeCast.selector);
        permit2Lib.simplePermit2(nonPermitToken, PK_OWNER, address(0xCAFE), 2 ** 170, block.timestamp, v, r, s);
    }

    function testSimplePermit2() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(token), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(token),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        Permit2Lib.simplePermit2(token, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
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
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(token), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(token),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        Permit2Lib.permit2(token, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testPermit2NonPermitToken() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(nonPermitToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(nonPermitToken),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        Permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testPermit2WETH9Mainnet() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(weth9Mainnet), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(weth9Mainnet),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        Permit2Lib.permit2(weth9Mainnet, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testPermit2NonPermitFallback() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(fallbackToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(fallbackToken),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        uint256 gas1 = gasleft();

        Permit2Lib.permit2(ERC20(address(fallbackToken)), PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertLt(gas1 - gasleft(), 50000); // If unbounded the staticcall will consume a wild amount of gas.
    }

    function testPermit2SmallerDS() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(lessDSToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(lessDSToken),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        Permit2Lib.permit2(MockERC20(address(lessDSToken)), PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        (uint160 amount,,) = permit2.allowance(PK_OWNER, address(lessDSToken), address(0xCAFE));
        assertEq(amount, 1e18);
    }

    function testPermit2LargerDS() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(largerDSToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(largerDSToken),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        Permit2Lib.permit2(MockERC20(address(largerDSToken)), PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        (uint160 amount,,) = permit2.allowance(PK_OWNER, address(largerDSToken), address(0xCAFE));
        assertEq(amount, 1e18);
    }

    function testPermit2LargerDSRevert() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    TEST_LG_DS_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH, PK_OWNER, address(0xB00B), 1e18, token.nonces(PK_OWNER), block.timestamp
                        )
                    )
                )
            )
        );
        // cannot recover signature
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        permit2Lib.permit2(MockERC20(address(largerDSToken)), PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testPermit2SmallerDSNoRevert() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PK,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    TEST_SML_DS_DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            PK_OWNER,
                            address(0xB00B),
                            1e18,
                            lessDSToken.nonces(PK_OWNER),
                            block.timestamp
                        )
                    )
                )
            )
        );

        Permit2Lib.permit2(lessDSToken, PK_OWNER, address(0xB00B), 1e18, block.timestamp, v, r, s);
    }

    /*/////////////////f/////////////////////////////////////////////
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

    function testTransferFrom2InvalidAmount() public {
        vm.startPrank(address(0xCAFE));
        vm.expectRevert(SafeCast160.UnsafeCast.selector);
        permit2Lib.transferFrom2(nonPermitToken, PK_OWNER, address(0xB00B), 2 ** 170);
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
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(nonPermitToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(nonPermitToken),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        vm.startPrank(address(0xCAFE));

        snapStart("permit2 + transferFrom2 with a non EIP-2612 native token");

        Permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        Permit2Lib.transferFrom2(nonPermitToken, PK_OWNER, address(0xB00B), 1e18);

        snapEnd();
    }

    function testPermit2PlusTransferFrom2WithNonPermitFallback() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(fallbackToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(fallbackToken),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        vm.startPrank(address(0xCAFE));

        snapStart("permit2 + transferFrom2 with a non EIP-2612 native token with fallback");

        Permit2Lib.permit2(ERC20(address(fallbackToken)), PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        Permit2Lib.transferFrom2(ERC20(address(fallbackToken)), PK_OWNER, address(0xB00B), 1e18);

        snapEnd();
    }

    function testPermit2PlusTransferFrom2WithWETH9Mainnet() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(weth9Mainnet), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(weth9Mainnet),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        vm.startPrank(address(0xCAFE));

        snapStart("permit2 + transferFrom2 with WETH9's mainnet address");

        Permit2Lib.permit2(weth9Mainnet, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        Permit2Lib.transferFrom2(weth9Mainnet, PK_OWNER, address(0xB00B), 1e18);

        snapEnd();
    }

    function testSimplePermit2PlusTransferFrom2WithNonPermit() public {
        (,, uint48 nonce) = permit2.allowance(PK_OWNER, address(nonPermitToken), address(0xCAFE));

        IAllowanceTransfer.PermitSingle memory permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(nonPermitToken),
                amount: 1e18,
                expiration: type(uint48).max,
                nonce: nonce
            }),
            spender: address(0xCAFE),
            sigDeadline: block.timestamp
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, PK, PERMIT2_DOMAIN_SEPARATOR);

        vm.startPrank(address(0xCAFE));

        snapStart("simplePermit2 + transferFrom2 with a non EIP-2612 native token");

        Permit2Lib.permit2(nonPermitToken, PK_OWNER, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        Permit2Lib.transferFrom2(nonPermitToken, PK_OWNER, address(0xB00B), 1e18);

        snapEnd();
    }

    // mock tests
    function testPermit2DSLessToken() public {
        bool success = permit2Lib.testPermit2Code(MockERC20(address(lessDSToken)));
        assertEq(success, true);
    }

    function testPermit2DSMoreToken() public {
        bool success = permit2Lib.testPermit2Code(MockERC20(address(largerNonStandardDSToken)));
        assertEq(success, false);
    }

    function testPermit2DSMore32Token() public {
        bool success = permit2Lib.testPermit2Code(MockERC20(address(largerDSToken)));
        assertEq(success, false);
    }
}
