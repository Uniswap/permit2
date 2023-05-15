// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";

contract CompactSignature is Test, PermitSignature {
    /// test cases pulled from EIP-2098
    function testCompactSignature27() public {
        bytes32 r = 0x68a020a209d3d56c46f38cc50a33f704f4a9a10a59377f8dd762ac66910e9b90;
        bytes32 s = 0x7e865ad05c4035ab5792787d4a0297a43617ae897930a6fe4d822b8faea52064;
        uint8 v = 27;

        bytes32 vs;
        (r, vs) = _getCompactSignature(v, r, s);

        assertEq(r, 0x68a020a209d3d56c46f38cc50a33f704f4a9a10a59377f8dd762ac66910e9b90);
        assertEq(vs, 0x7e865ad05c4035ab5792787d4a0297a43617ae897930a6fe4d822b8faea52064);
    }

    function testCompactSignature28() public {
        bytes32 r = 0x9328da16089fcba9bececa81663203989f2df5fe1faa6291a45381c81bd17f76;
        bytes32 s = 0x139c6d6b623b42da56557e5e734a43dc83345ddfadec52cbe24d0cc64f550793;
        uint8 v = 28;

        bytes32 vs;
        (r, vs) = _getCompactSignature(v, r, s);

        assertEq(r, 0x9328da16089fcba9bececa81663203989f2df5fe1faa6291a45381c81bd17f76);
        assertEq(vs, 0x939c6d6b623b42da56557e5e734a43dc83345ddfadec52cbe24d0cc64f550793);
    }
}
