// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./ifo.sol";

contract Orderbook {
    event BuyOrderPosted(uint _oid,  address _host, uint _amount, uint _price);
    event SellOrderPosted(uint _oid,  address _host, uint _amount, uint _price);
    event BuyOrderEdited(uint _oid,  address _host, uint _newAmount, uint _newPrice);
    event SellOrderEdited(uint _oid,  address _host, uint _newAmount, uint _newPrice);
    event BuyOrderRemoved(uint _oid, address _host);
    event SellOrderRemoved(uint _oid, address _host);
    event BuyOrderFulfilled(uint _oid, address _buyer, address _seller, uint _amount, uint _price);
    event SellOrderFulfilled(uint _oid, address _buyer, address _seller, uint _amount, uint _price);

    enum OrderType {
        buy,
        sell
    }

    struct Order {        
        OrderType orderType;
        uint256 amount;
        uint256 timestamp;
    }

    Order[] public orders;

    constructor() {
        
    }

    function postBuyOrder(uint _amount) external payable {
        
    }

    function postSellOrder(uint _amount) external {
        

    }

    function editBuyOrder(uint _postId, uint _amount) external payable {

    }

    function editSellOrder(uint _postId, uint _amount) external {

    }

    function removeBuyOrder(uint _postId) external {
        
    }

    function removeSellOrder(uint _postId) external {

    }

    function placeSellOrder(uint _postId) external payable {

    }

    function placeBuyOrder(uint _postId) external payable {

    }
}