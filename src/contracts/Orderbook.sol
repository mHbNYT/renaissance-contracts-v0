// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./ifo.sol";

contract Orderbook {
    using SafeERC20 for IERC20;

    event BuyOrderPosted(uint _oid,  address _host, uint _amount, uint _price);
    event SellOrderPosted(uint _oid,  address _host, uint _amount, uint _price);    
    event BuyOrderRemoved(uint _oid, address _host);
    event SellOrderRemoved(uint _oid, address _host);
    event BuyOrderFulfilled(uint _oid, address _buyer, address _seller, uint _amount);
    event SellOrderFulfilled(uint _oid, address _buyer, address _seller, uint _amount);

    error EthAmountDifferent();   
    error NotEnoughFNFT();
    error OnlyOrderHost();
    error WrongOrderType();
    error NotEnoughBalance();
    error NotEnoughPayment();
    error NotEnoughAvailable();

    enum OrderType {
        buy,
        sell
    }

    struct Order {        
        OrderType orderType;
        address host;
        uint256 amount;
        uint256 price;
        uint256 blockNumber;
    }

    IERC20 public fNFT;
    Order[] public orders;
    mapping(address => uint256) public totalEthInEscrow;
    mapping(address => uint256) public totalFNFTInEscrow;

    constructor(address _fNFT) {
        fNFT = IERC20(_fNFT);
    }

    function postBuyOrder(uint _amount, uint _price) external payable {
        if (_amount * _price != msg.value) revert EthAmountDifferent();
        
        orders.push(Order(OrderType.buy, msg.sender, _amount, _price, block.number));
        totalEthInEscrow[msg.sender] += msg.value;

        emit BuyOrderPosted(orders.length - 1, msg.sender, _amount, _price);
    }

    function postSellOrder(uint _amount, uint _price) external {
        if (_amount > fNFT.balanceOf(msg.sender)) revert NotEnoughFNFT();

        orders.push(Order(OrderType.sell, msg.sender, _amount, _price, block.number));
        totalFNFTInEscrow[msg.sender] += _amount;

        fNFT.safeTransferFrom(msg.sender, address(this), _amount);

        emit SellOrderPosted(orders.length - 1, msg.sender, _amount, _price);
    }

    function removeBuyOrder(uint _oid) external {
        Order memory order = orders[_oid];        
        if (msg.sender != order.host) revert OnlyOrderHost();
        if (order.orderType != OrderType.buy) revert WrongOrderType();                
        if (totalEthInEscrow[msg.sender] < order.amount * order.price) revert NotEnoughBalance();

        totalEthInEscrow[msg.sender] -= order.amount * order.price;
        delete orders[_oid];

        payable(msg.sender).transfer(order.amount * order.price);        
    }

    function removeSellOrder(uint _oid) external {
        Order memory order = orders[_oid];        
        if (msg.sender != order.host) revert OnlyOrderHost();
        if (order.orderType != OrderType.sell) revert WrongOrderType();                
        if (totalFNFTInEscrow[msg.sender] < order.amount) revert NotEnoughBalance();

        totalFNFTInEscrow[msg.sender] -= order.amount;
        delete orders[_oid];

        fNFT.safeTransferFrom(address(this), msg.sender, order.amount);
    }

    function buy(uint _oid, uint _amount) external payable {
        Order storage order = orders[_oid];

        if (_amount * order.price < msg.value) revert NotEnoughPayment();
        if (order.amount < _amount) revert NotEnoughAvailable();

        order.amount -= _amount;
        totalFNFTInEscrow[order.host] -= _amount;

        payable(order.host).transfer(msg.value);
        fNFT.safeTransferFrom(address(this), msg.sender, _amount);
    }

    function sell(uint _oid, uint _amount) external payable {

    }
}