import {ERC20} from "solmate/tokens/ERC20.sol";
import {Permit2Lib} from "../../src/libraries/Permit2Lib.sol";

contract MockPermit2Lib {
    function permit2(
        ERC20 token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        Permit2Lib.permit2(token, owner, spender, amount, deadline, v, r, s);
    }
}
