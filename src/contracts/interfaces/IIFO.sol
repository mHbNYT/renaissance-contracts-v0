//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIFO {
    function fnftLocked() external view returns (bool);

    function ended() external view returns (bool);

    function lockedSupply() external view returns (uint256);
}
