pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {Permit2} from "../src/Permit2.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {SignatureVerification} from "../src/libraries/SignatureVerification.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {Permitter} from "./actors/Permitter.sol";
import {Spender} from "./actors/Spender.sol";

contract Runner {
    Permit2 public permit2;
    Permitter public permitter1;
    Permitter public permitter2;
    Spender public spender1;
    Spender public spender2;
    MockERC20 public token;
    uint256 private index;

    address[] owners;
    IAllowanceTransfer.PermitSingle[] permits;
    bytes[] sigs;

    constructor(Permit2 _permit2) {
        permit2 = _permit2;
        token = new MockERC20("TEST", "test", 18);
        permitter1 = new Permitter(_permit2, token, 0x01);
        permitter2 = new Permitter(_permit2, token, 0x02);
        spender1 = new Spender(_permit2, token);
        spender2 = new Spender(_permit2, token);
    }

    function createPermit(uint128 amount, bool firstPermitter, bool firstSpender) public {
        Permitter permitter = firstPermitter ? permitter1 : permitter2;
        Spender spender = firstSpender ? spender1 : spender2;
        (IAllowanceTransfer.PermitSingle memory permit, bytes memory sig) =
            permitter.createPermit(amount, address(spender));
        permits.push(permit);
        sigs.push(sig);
        owners.push(address(permitter.signer()));
    }

    function approve(uint128 amount, bool firstPermitter, bool firstSpender) public {
        Permitter permitter = firstPermitter ? permitter1 : permitter2;
        Spender spender = firstSpender ? spender1 : spender2;
        permitter.approve(amount, address(spender));
    }

    // always uses permits in order for nonces
    function usePermit() public {
        if (permits.length <= index) {
            return;
        }
        permit2.permit(owners[index], permits[index], sigs[index]);
        index++;
    }

    function spendPermit(uint160 amount, bool firstPermitter, bool firstSpender) public {
        Permitter permitter = firstPermitter ? permitter1 : permitter2;
        Spender spender = firstSpender ? spender1 : spender2;
        spender.spendPermit(amount, address(permitter.signer()));
    }

    function amountPermitted() public view returns (uint256) {
        return permitter1.amountPermitted() + permitter2.amountPermitted();
    }

    function amountSpent() public view returns (uint256) {
        return spender1.amountSpent() + spender2.amountSpent();
    }

    function balanceOf(address who) public view returns (uint256) {
        return token.balanceOf(who);
    }
}

contract AllowanceTransferInvariants is StdInvariant, Test {
    Permit2 permit2;
    Runner runner;
    MockERC20 token;

    function setUp() public {
        permit2 = new Permit2();
        runner = new Runner(permit2);

        targetContract(address(runner));
        targetSender(address(vm.addr(0xb0b0)));
    }

    function invariant_spendNeverExceedsPermit() public {
        uint256 permitted = runner.amountPermitted();
        uint256 spent = runner.amountSpent();
        assertGe(permitted, spent);
    }

    function invariant_balanceEqualsSpent() public {
        uint256 spent = runner.amountSpent();
        assertEq(runner.balanceOf(address(runner.spender1())) + runner.balanceOf(address(runner.spender2())), spent);
    }

    function invariant_permit2NeverHoldsBalance() public {
        assertEq(runner.balanceOf(address(permit2)), 0);
    }
}
