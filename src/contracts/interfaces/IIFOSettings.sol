//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIFOSettings {
    function creatorIFOLock() external view returns (bool);

    function minimumDuration() external view returns (uint256);

    function maximumDuration() external view returns (uint256);

    function creatorUtilityContract() external view returns (address);

    function governanceFee() external view returns (uint256);

    function feeReceiver() external view returns (address payable);
}
