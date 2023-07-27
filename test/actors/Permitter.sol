pragma solidity 0.8.17;

import {Vm} from "forge-std/Vm.sol";
import {Permit2} from "../../src/Permit2.sol";
import {IAllowanceTransfer} from "../../src/interfaces/IAllowanceTransfer.sol";
import {PermitSignature} from "../utils/PermitSignature.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract Permitter is PermitSignature {
    uint256 private immutable privateKey;
    Permit2 private immutable permit2;
    MockERC20 private immutable token;
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address public immutable signer;

    mapping(address => uint48) private nonces;
    uint256 public amountPermitted;

    constructor(Permit2 _permit2, MockERC20 _token, uint256 _privateKey) {
        permit2 = _permit2;
        token = _token;
        privateKey = _privateKey;

        signer = vm.addr(privateKey);
        token.mint(signer, type(uint160).max);
        vm.prank(signer);
        token.approve(address(permit2), type(uint256).max);
    }

    function createPermit(uint128 amount, address spender)
        public
        returns (IAllowanceTransfer.PermitSingle memory permit, bytes memory sig)
    {
        uint48 nonce = nonces[spender];
        permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(token),
                amount: amount,
                expiration: uint48(block.timestamp + 1000),
                nonce: nonce
            }),
            spender: spender,
            sigDeadline: block.timestamp + 1000
        });
        sig = getPermitSignature(permit, privateKey, permit2.DOMAIN_SEPARATOR());

        nonces[spender]++;
        amountPermitted += amount;
    }

    function approve(uint128 amount, address spender) public {
        permit2.approve(address(token), spender, uint160(amount), uint48(block.timestamp + 1000));
        amountPermitted += amount;
    }
}
