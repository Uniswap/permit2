// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/draft-EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Permit2ERC721} from "../../src/ERC721/Permit2ERC721.sol";
import {PermitHashERC721} from "../../src/ERC721/libraries/PermitHashERC721.sol";
import {IAllowanceTransferERC721} from "../../src/ERC721/interfaces/IAllowanceTransferERC721.sol";
import {ISignatureTransferERC721} from "../../src/ERC721/interfaces/ISignatureTransferERC721.sol";

contract PermitSignatureERC721 is Test {
    function defaultERC721PermitAllowance(address token, uint256 tokenId, uint48 expiration, uint48 nonce)
        public
        returns (IAllowanceTransferERC721.PermitSingle memory)
    {
        IAllowanceTransferERC721.PermitDetails memory details = IAllowanceTransferERC721.PermitDetails({
            token: token,
            tokenId: tokenId,
            expiration: expiration,
            nonce: nonce
        });
        return IAllowanceTransferERC721.PermitSingle({
            details: details,
            spender: address(this),
            sigDeadline: block.timestamp + 100
        });
    }

    function defaultERC20PermitBatchAllowance(address[] memory tokens, uint48 expiration, uint48 nonce)
        internal
        view
        returns (IAllowanceTransferERC721.PermitBatch memory)
    {
        IAllowanceTransferERC721.PermitDetails[] memory details =
            new IAllowanceTransferERC721.PermitDetails[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            details[i] = IAllowanceTransferERC721.PermitDetails({
                token: tokens[i],
                // the tokenId minted is based on the index i in TokenProvider
                tokenId: i,
                expiration: expiration,
                nonce: nonce
            });
        }

        return IAllowanceTransferERC721.PermitBatch({
            details: details,
            spender: address(this),
            sigDeadline: block.timestamp + 100
        });
    }

    function getPermitSignatureRaw(
        IAllowanceTransferERC721.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 permitHash = keccak256(abi.encode(PermitHashERC721._PERMIT_DETAILS_TYPEHASH, permit.details));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(PermitHashERC721._PERMIT_SINGLE_TYPEHASH, permitHash, permit.spender, permit.sigDeadline)
                )
            )
        );

        (v, r, s) = vm.sign(privateKey, msgHash);
    }

    function getPermitSignature(
        IAllowanceTransferERC721.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        return bytes.concat(r, s, bytes1(v));
    }

    function getCompactPermitSignature(
        IAllowanceTransferERC721.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        bytes32 vs;
        (r, vs) = _getCompactSignature(v, r, s);
        return bytes.concat(r, vs);
    }

    function _getCompactSignature(uint8 vRaw, bytes32 rRaw, bytes32 sRaw)
        internal
        pure
        returns (bytes32 r, bytes32 vs)
    {
        uint8 v = vRaw - 27; // 27 is 0, 28 is 1
        vs = bytes32(uint256(v) << 255) | sRaw;
        return (rRaw, vs);
    }

    function getPermitBatchSignature(
        IAllowanceTransferERC721.PermitBatch memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal returns (bytes memory sig) {
        bytes32[] memory permitHashes = new bytes32[](permit.details.length);
        for (uint256 i = 0; i < permit.details.length; ++i) {
            permitHashes[i] = keccak256(abi.encode(PermitHashERC721._PERMIT_DETAILS_TYPEHASH, permit.details[i]));
        }
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        PermitHashERC721._PERMIT_BATCH_TYPEHASH,
                        keccak256(abi.encodePacked(permitHashes)),
                        permit.spender,
                        permit.sigDeadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }
}
