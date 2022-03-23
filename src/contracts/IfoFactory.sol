// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Ifo.sol";

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
        require( ifo[_fNFT] == address(0), "Ifo: exists");
        require( _fNFT != address(0), "Ifo: _fNFT 0");
        require( IfNFT( address(_fNFT) ).balanceOf(msg.sender) == IfNFT( address(_fNFT) ).totalSupply(), "Ifo: not owner" );
        require( _amountForSale != 0, "Ifo: amountForSale 0");
        require( _amountForSale <= IfNFT( address(_fNFT) ).balanceOf(msg.sender), "Ifo: amountForSale over limit");        
        require( _amountForSale % _cap == 0, "Ifo: amountForSale undivisible");
        require( _price != 0, "Ifo: price 0" );
        require( _cap != 0, "Ifo: cap 0" );

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