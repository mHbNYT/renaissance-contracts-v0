//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFNFT {
    function balanceOf(address _account) external returns (uint256);

    function totalSupply() external returns (uint256);

    function auctionState() external returns (uint256);

    function initialReserve() external returns (uint256);

    function userReservePrice(address _user) external returns (uint256);
}
