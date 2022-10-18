pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {AllowanceMath} from "../src/AllowanceMath.sol";

contract PackedAllowanceTest is Test {
    using AllowanceMath for uint256;

    function testUnpackAllowanceTimestampEdges() public {
        uint256 word = 0x800000000000000100000000;

        (uint160 amount, uint64 timestamp, uint32 nonce) = AllowanceMath.unpack(word);

        assertEq(nonce, 0);
        assertEq(timestamp, 9223372036854775809);
        assertEq(amount, 0);
    }

    function testUnpackAllowanceNonceEdges() public {
        uint256 word = 0x10000001;
        (uint160 amount, uint64 timestamp, uint32 nonce) = AllowanceMath.unpack(word);

        assertEq(nonce, 268435457);
        assertEq(timestamp, 0);
        assertEq(amount, 0);
    }

    function testUnpackAllowanceAmountEdges() public {
        uint256 word = 0x8000000000000000000000000000000000000001000000000000000000000000;
        (uint160 amount, uint64 timestamp, uint32 nonce) = AllowanceMath.unpack(word);

        assertEq(nonce, 0);
        assertEq(timestamp, 0);
        assertEq(amount, 730750818665451459101842416358141509827966271489);
    }

    function testPackAllowanceTimestampValid() public {
        uint64 timestamp = 9223372036854775809;
        uint256 word = AllowanceMath.pack(0, timestamp, 0);
        assertEq(word, 0x800000000000000100000000);
    }

    function testPackAllowanceTimestampDirtied() public {
        uint256 dirtyTimestamp = 0x18000000000000001;
        uint256 word = AllowanceMath.pack(0, uint64(dirtyTimestamp), 0);
        assertEq(word, 0x800000000000000100000000);
    }

    function testPackAllowanceNonceValid() public {
        uint32 nonce = 0x10000001;
        uint256 word = AllowanceMath.pack(0, 0, nonce);
        assertEq(word, 0x10000001);
    }

    function testPackAllowanceNonceDirty() public {
        uint256 nonceDirty = 0xF10000001;
        uint256 word = AllowanceMath.pack(0, 0, uint32(nonceDirty));
        assertEq(word, 0x10000001);
    }

    function testPackAllowanceAmountValid() public {
        uint160 amount = uint160(0x8000000000000000000000000000000000000001);
        uint256 word = AllowanceMath.pack(amount, 0, 0);
        assertEq(word, 0x8000000000000000000000000000000000000001000000000000000000000000);
    }

    function testPackAllowanceAmountDirty() public {
        uint256 amount = uint256(0x018000000000000000000000000000000000000001);
        uint256 word = AllowanceMath.pack(uint160(amount), 0, 0);
        assertEq(word, 0x8000000000000000000000000000000000000001000000000000000000000000);
    }

    function testSetAmount() public {
        uint160 oldAmount = 11 ** 18; // 0x4D28CB56C33FA539
        uint64 oldTimestamp = 5000000000; // 0x12A05F200
        uint32 oldNonce = 0;

        uint256 oldWord = AllowanceMath.pack(oldAmount, oldTimestamp, 0);
        assertEq(oldWord, uint256(0x0004d28CB56c33fa539000000012A05f20000000000));

        uint160 newAmount = uint160(10 ** 18);
        uint256 newWord = oldWord.setAmount(newAmount);

        assertEq(newWord, uint256(0x000DE0B6B3A7640000000000012A05F20000000000));
        assertEq(newAmount, newWord.amount());
        assertEq(newWord.timestamp(), oldTimestamp);
        assertEq(newWord.nonce(), oldNonce);
    }
}
