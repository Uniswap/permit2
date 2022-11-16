// SPDX-License-Identifier: AGPL-3.0-or-later
// from: https://github.com/maple-labs/contract-test-utils/blob/add-bounded-invariants/contracts/test.sol
pragma solidity 0.8.17;

contract InvariantTest {
    address[] private _excludedContracts;
    address[] private _targetContracts;
    address[] private _targetSenders;

    function addTargetContract(address newTargetContract_) internal {
        _targetContracts.push(newTargetContract_);
    }

    function targetContracts() public view returns (address[] memory targetContracts_) {
        require(_targetContracts.length != uint256(0), "NO_TARGET_CONTRACTS");
        return _targetContracts;
    }

    function addTargetSender(address newTargetSender_) internal {
        _targetSenders.push(newTargetSender_);
    }

    function targetSenders() public view returns (address[] memory targetSenders_) {
        require(_targetSenders.length != uint256(0), "NO_TARGET_SENDERS");
        return _targetSenders;
    }

    function excludeContract(address newExcludedContract_) internal {
        _excludedContracts.push(newExcludedContract_);
    }

    function excludeContracts() public view returns (address[] memory excludedContracts_) {
        require(_excludedContracts.length != uint256(0), "NO_TARGET_CONTRACTS");
        return _excludedContracts;
    }
}
