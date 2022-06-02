// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IEligibilityManager {
    function deployEligibility(uint256 vaultId, bytes calldata initData)
        external
        returns (address);
}
