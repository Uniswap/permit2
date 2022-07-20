// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// todo: could use create2 based system for some interesting properties
// todo: multicall or at least batch revoke approval thing (lock down all approvals)
//

contract Approve2 {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                            DANGERLIST LOGIC
    //////////////////////////////////////////////////////////////*/

    uint128 constant PARADIGM_DANGERLIST = 0;

    uint128 constant OPT_OUT_DANGERLIST = type(uint128).max;

    mapping(uint128 => address) dangerListOwners;

    mapping(uint128 => mapping(address => bool)) dangerList;

    constructor() {
        // Reserve the opt out danger list for this contract.
        dangerListOwners[OPT_OUT_DANGERLIST] = address(this);
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-712 STORAGE
    //////////////////////////////////////////////////////////////*/

    struct UserData {
        uint128 nonce;
        uint128 dangerListId;
    }

    // todo: raw bitpacking would be cheaper

    mapping(address => UserData) public getUserData;

    mapping(address => mapping(address => bool)) isApprovedForAll;

    function DOMAIN_SEPARATOR(address token) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("Approve2"), // We use unique a unique name and version spender ensure
                    keccak256("Approve2 v1"), // if the token ever adds permit support we don't collide.
                    block.chainid,
                    token // We use the token's address for easy frontend compatibility.
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOWANCE STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(ERC20 => mapping(address => mapping(address => uint256))) public allowance;

    event Permit(ERC20 indexed token, address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            APPROVE ALL LOGIC
    //////////////////////////////////////////////////////////////*/

    function setIsApprovedForAll(address spender, bool approvedAll) public {
        // Ensure the spender is not on the user's chosen danger list.
        require(isOnDangerList(getUserData[msg.sender].dangerListId, spender), "SPENDER_IS_DANGEROUS");

        isApprovedForAll[msg.sender][spender] = approvedAll;

        // todo: event?
    }

    function permitAll(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        unchecked {
            require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

            // todo: does inlining this increase gas?
            uint256 nonce = ++getUserData[owner].nonce; // Get and preemptively increment the user's nonce.

            // Ensure the spender is not on the user's chosen danger list.
            require(isOnDangerList(getUserData[owner].dangerListId, spender), "SPENDER_IS_DANGEROUS");

            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(address(this)),
                        keccak256(
                            abi.encode(
                                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                                owner,
                                spender,
                                value,
                                nonce,
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

            isApprovedForAll[owner][spender] = true;

            // todo: event?
        }
    }

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
    ) external {
        unchecked {
            require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

            // todo: does inlining this increase gas?
            uint256 nonce = ++getUserData[owner].nonce; // Get and preemptively increment the user's nonce.

            // Ensure the spender is not on the user's chosen danger list.
            require(isOnDangerList(getUserData[owner].dangerListId, spender), "SPENDER_IS_DANGEROUS");

            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(token),
                        keccak256(
                            abi.encode(
                                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                                owner,
                                spender,
                                value,
                                nonce,
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

            emit Permit(token, owner, spender, value);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferFrom(
        ERC20 token,
        address from,
        address spender,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = allowance[token][from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max)
            if (allowed >= amount) allowance[token][from][msg.sender] = allowed - amount;
            else require(isApprovedForAll[from][msg.sender], "APPROVE_ALL_REQUIRED");

        token.safeTransferFrom(from, spender, amount);

        // TODO: event?

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             USER DATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function invalidateNonce() external {
        ++getUserData[msg.sender].nonce;
    }

    function optOutOfDangerList() external {
        chooseDangerList(OPT_OUT_DANGERLIST);
    }

    function chooseDangerList(uint128 dangerListId) public {
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

    function isOnDangerList(uint128 dangerListId, address spender) public view returns (bool) {
        if (dangerListId == OPT_OUT_DANGERLIST) return false;

        return dangerList[dangerListId][spender];
    }
}
