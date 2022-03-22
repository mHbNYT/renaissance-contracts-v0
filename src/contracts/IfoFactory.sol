// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ifo.sol";

interface IIfo {
    function balanceOf(address _account) external returns(uint256);
    function totalSupply() external returns(uint256);
}

contract IfoFactory is Ownable {
    mapping(address => address) public ifo;

    event IfoCreated(
        address indexed _fNFT, 
        address indexed _ifo, 
        address _creator, 
        uint256 _amount, 
        uint256 _price, 
        uint256 _cap
    );

    error AlreadyExists();
    error InvalidAddress();
    error OnlyFullOwner();
    error InvalidAmountForSale();
    error PriceZero();
    error CapZero();

    function createIFO(
        address _fNFT,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        bool _allowWhitelisting
    ) external returns(address) {
        if ( ifo[_fNFT] == address(0) ) revert AlreadyExists();
        if ( _fNFT == address(0) ) revert InvalidAddress();
        if (IfNFT( address(_fNFT) ).balanceOf(msg.sender) != IfNFT( address(_fNFT) ).totalSupply() ) revert OnlyFullOwner();
        if (
            _amountForSale == 0 || 
            _amountForSale > IfNFT( address(_fNFT) ).balanceOf(msg.sender) || 
            _amountForSale % _cap != 0
        ) revert InvalidAmountForSale();
        if ( _price == 0 ) revert PriceZero();
        if ( _cap == 0 ) revert CapZero();

        address _ifo = address(new Ifo(
            _fNFT,
            _amountForSale,
            _price,
            _cap,
            _allowWhitelisting
        ));

        ifo[_fNFT] = _ifo;

        emit IfoCreated(_fNFT, _ifo, msg.sender, _amountForSale, _price, _cap);

        return _ifo;
    }
}