// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IMultiProxyController {    
    function deployerUpdateProxy(string memory key, address proxy) external;
}