pragma solidity 0.8.17;

import "ds-test/test.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {Permit, Signature, InvalidSignature} from "../src/Permit2Utils.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {InvariantTest} from "./utils/InvariantTest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract Permitter is PermitSignature {
    Permit2 private permit2;
    MockERC20 private token;
    uint32 private nonce;
    Vm private vm;
    address private runner;
    uint256 private privateKey = 0x1234567890;
    uint256 public amountPermitted;

    constructor(Vm _vm, Permit2 _permit2, MockERC20 _token) {
        vm = _vm;
        permit2 = _permit2;
        token = _token;
        token.mint(vm.addr(privateKey), type(uint160).max);
        vm.prank(vm.addr(privateKey));
        token.approve(address(permit2), type(uint256).max);
        runner = msg.sender;
    }

    function createPermit(uint128 amount) public returns (Permit memory permit, Signature memory sig) {
        permit = defaultERC20PermitAllowance(address(token), amount, uint64(block.timestamp + 1000));
        sig = getPermitSignature(vm, permit, nonce, privateKey, permit2.DOMAIN_SEPARATOR());

        nonce++;
        amountPermitted += amount / 2;
    }
}

contract Spender {
    Permit2 private permit2;
    MockERC20 private token;
    address private from;
    address private runner;
    Vm private vm;
    uint256 public amountSpent;

    constructor(Vm _vm, Permit2 _permit2, MockERC20 _token, address _from) {
        vm = _vm;
        permit2 = _permit2;
        token = _token;
        from = _from;
        runner = msg.sender;
    }

    function spendPermit(Permit memory permit, Signature memory sig, uint160 amount) public {
        permit2.transferFrom(address(token), from, address(0), amount);
        amountSpent += amount;
    }
}

contract Runner {
    Permitter public permitter;
    Spender public spender;
    MockERC20 public token;
    Vm private vm;

    Permit[] permits;
    Signature[] sigs;

    constructor(Vm _vm, Permit2 _permit2) {
        vm = _vm;
        token = new MockERC20("TEST", "test", 18);
        permitter = new Permitter(_vm, _permit2, token);
        spender = new Spender(_vm, _permit2, token, address(permitter));
    }

    function createPermit(uint128 amount) public {
        (Permit memory permit, Signature memory sig) = permitter.createPermit(amount);
        permits.push(permit);
        sigs.push(sig);
    }

    function usePermit(uint8 index) public {
        spender.spendPermit(permits[0], sigs[0], uint160(permits[0].amount));
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

struct FuzzSelector {
    address addr;
    bytes4[] selectors;
}

contract AllowanceTransferInvariants is DSTest, InvariantTest {
    Permit2 permit2;
    Runner runner;
    MockERC20 token;

    function setUp() public {
        permit2 = new Permit2();
        runner = new Runner(Vm(HEVM_ADDRESS), permit2);

        excludeContract(address(runner.token()));
        excludeContract(address(runner.permitter()));
        excludeContract(address(runner.spender()));
        addTargetContract(address(runner));
    }

    function invariant_spendNeverExceedsPermit() public {
        uint256 permitted = runner.amountPermitted();
        uint256 spent = runner.amountSpent();
        require(permitted <= spent, "spend exceeds");
        require(runner.balanceOf(address(0)) == 0, "transfer");
    }

    function targetSelectors() public returns (FuzzSelector[] memory) {
        FuzzSelector[] memory targets = new FuzzSelector[](2);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Runner.createPermit.selector;
        targets[0] = FuzzSelector(address(runner), selectors);
        selectors[1] = Runner.usePermit.selector;
        targets[1] = FuzzSelector(address(runner), selectors);
        return targets;
    }
}
