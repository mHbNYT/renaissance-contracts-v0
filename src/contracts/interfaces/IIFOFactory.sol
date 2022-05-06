//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIFOFactory {
    function getIFO(address _fnft) external view returns (address);
}
