pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {SignatureVerification} from "../src/libraries/SignatureVerification.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {InvariantTest} from "./utils/InvariantTest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract Permitter is PermitSignature {
    Permit2 private permit2;
    MockERC20 private token;
    uint48 private nonce;
    Runner private runner;
    uint256 private privateKey = 0x1234567890;
    address public signer;
    uint256 public amountPermitted;

    constructor(Permit2 _permit2, MockERC20 _token) {
        permit2 = _permit2;
        token = _token;
        signer = vm.addr(privateKey);
        token.mint(signer, type(uint160).max);
        vm.prank(signer);
        token.approve(address(permit2), type(uint256).max);
        runner = Runner(msg.sender);
    }

    function createPermit(uint128 amount)
        public
        returns (IAllowanceTransfer.PermitSingle memory permit, bytes memory sig)
    {
        permit = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(token),
                amount: amount,
                expiration: uint48(block.timestamp + 1000),
                nonce: nonce
            }),
            spender: address(runner.spender()),
            sigDeadline: block.timestamp + 1000
        });
        sig = getPermitSignature(permit, privateKey, permit2.DOMAIN_SEPARATOR());

        nonce++;
        amountPermitted += amount;
    }
}

contract Spender is Test {
    Permit2 private permit2;
    MockERC20 private token;
    address private from;
    Runner private runner;
    uint256 public amountSpent;

    constructor(Permit2 _permit2, MockERC20 _token, address _from) {
        permit2 = _permit2;
        token = _token;
        from = _from;
        runner = Runner(msg.sender);
    }

    function spendPermit(uint160 amount) public {
        (uint160 allowance, uint48 expiry,) = permit2.allowance(from, address(token), address(this));
        if (expiry < block.timestamp) return;
        amount = uint160(bound(amount, 0, allowance));
        permit2.transferFrom(from, address(this), amount, address(token));
        amountSpent += amount;
    }
}

contract Runner {
    Permit2 public permit2;
    Permitter public permitter;
    Spender public spender;
    MockERC20 public token;
    uint256 private index;

    IAllowanceTransfer.PermitSingle[] permits;
    bytes[] sigs;

    constructor(Permit2 _permit2) {
        permit2 = _permit2;
        index = 0;
        token = new MockERC20("TEST", "test", 18);
        permitter = new Permitter(_permit2, token);
        spender = new Spender(_permit2, token, address(permitter.signer()));
    }

    function createPermit(uint128 amount) public {
        (IAllowanceTransfer.PermitSingle memory permit, bytes memory sig) = permitter.createPermit(amount);
        permits.push(permit);
        sigs.push(sig);
    }

    // always uses permits in order for nonces
    function usePermit() public {
        if (permits.length <= index) {
            return;
        }
        permit2.permit(permitter.signer(), permits[index], sigs[index]);
        index++;
    }

    // always uses permits in order for nonces
    function spendPermit(uint160 amount) public {
        spender.spendPermit(amount);
    }

    function amountPermitted() public view returns (uint256) {
        return permitter.amountPermitted();
    }

    function amountSpent() public view returns (uint256) {
        return spender.amountSpent();
    }

    function balanceOf(address who) public view returns (uint256) {
        return token.balanceOf(who);
    }
}

contract AllowanceTransferInvariants is Test, InvariantTest {
    Permit2 permit2;
    Runner runner;
    MockERC20 token;

    function setUp() public {
        permit2 = new Permit2();
        runner = new Runner(permit2);

        addTargetContract(address(runner));
        addTargetSender(address(vm.addr(0xb0b0)));
    }

    function invariant_spendNeverExceedsPermit() public {
        uint256 permitted = runner.amountPermitted();
        uint256 spent = runner.amountSpent();
        require(permitted >= spent, "spend exceeds");
        require(runner.balanceOf(address(runner.spender())) == spent, "balance not equal spent");
    }
}
