// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// todo: could use create2 based system for some interesting properties

contract Approve2 {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                            DANGERLIST LOGIC
    //////////////////////////////////////////////////////////////*/

    uint128 constant PARADIGM_DANGERLIST = 0;

    mapping(uint128 => address) dangerListOwners;

    mapping(uint128 => mapping(address => bool)) dangerList;

    /*//////////////////////////////////////////////////////////////
                             EIP-712 STORAGE
    //////////////////////////////////////////////////////////////*/

    struct UserData {
        uint128 nonce;
        uint128 dangerListId;
    }

    // todo: raw bitpacking would be cheaper

    mapping(address => UserData) public getUserData;

    mapping(address => mapping(address => bool)) hasApprovedAll;

    /*//////////////////////////////////////////////////////////////
                            ALLOWANCE STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(ERC20 => mapping(address => mapping(address => uint256))) public allowance;

    event Permit(ERC20 indexed token, address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            APPROVE ALL LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovedAll(address to, bool approvedAll) public {
        hasApprovedAll[msg.sender][to] = approvedAll;
    }

    // TODO: need a permit for this

    /*//////////////////////////////////////////////////////////////
                              PERMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        ERC20 token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        keccak256(
                            abi.encode(
                                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                                keccak256("Approve2"), // We use unique a unique name and version to ensure if
                                keccak256("Approve2 v1"), // the token ever adds permit support we don't collide.
                                block.chainid,
                                address(token) // We use the token's address for easy frontend compatibility.
                            )
                        ),
                        keccak256(
                            abi.encode(
                                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                                owner,
                                spender,
                                value,
                                ++getUserData[owner].nonce,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[token][recoveredAddress][spender] = value;
        }

        emit Permit(token, owner, spender, value);
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) external virtual returns (bool) {
        uint256 allowed = allowance[token][from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[token][from][msg.sender] = allowed - amount;

        token.safeTransferFrom(from, to, amount);

        // TODO: event?

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             USER DATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function invalidateNonce() external {
        ++getUserData[msg.sender].nonce;
    }

    function chooseDangerList(uint128 dangerListId) external {
        getUserData[msg.sender].dangerListId = dangerListId;
    }

    /*//////////////////////////////////////////////////////////////
                            DANGERLIST LOGIC
    //////////////////////////////////////////////////////////////*/

    function claimDangerlist(uint128 dangerListId) external {
        require(dangerListOwners[dangerListId] == address(0), "DANGERLIST_ALREADY_CLAIMED");

        dangerListOwners[dangerListId] = msg.sender;
    }

    function setDangerlistStatus(uint128 dangerListId, bool status) external {
        require(dangerListOwners[dangerListId] == msg.sender, "NOT_DANGERLIST_OWNER");

        dangerList[dangerListId][msg.sender] = status;
    }
}
