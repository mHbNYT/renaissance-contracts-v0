//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIFOSettings {
    function creatorIFOLock() external returns(bool);
    function minimumDuration() external returns(uint);
    function maximumDuration() external returns(uint);
    function creatorUtilityContract() external returns(address);
}