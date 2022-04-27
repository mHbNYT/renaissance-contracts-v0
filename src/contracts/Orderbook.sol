// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Orderbook is Ownable {
    using SafeERC20 for IERC20;

    event BuyOrderPosted(address _fNFT, uint256 _oid, address _host, uint256 _amount, uint256 _price);
    event SellOrderPosted(address _fNFT, uint256 _oid, address _host, uint256 _amount, uint256 _price);
    event BuyOrderRemoved(address _fNFT, uint256 _oid, address _host);
    event SellOrderRemoved(address _fNFT, uint256 _oid, address _host);
    event BuyOrderFulfilled(address _fNFT, uint256 _oid, address _buyer, address _seller, uint256 _amount);
    event SellOrderFulfilled(address _fNFT, uint256 _oid, address _buyer, address _seller, uint256 _amount);
    event FeeChanged(uint256 _oldFee, uint256 _newFee);
    event DaoChanged(address _oldDao, address _newDao);

    error FeeTooHigh();
    error InvalidAddress();
    error EthAmountDifferent();
    error NotEnoughFNFT();
    error OnlyOrderHost();
    error WrongOrderType();
    error NotEnoughBalance();
    error NotEnoughPayment();
    error NotEnoughSupply();
    error TxFailed();

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

    uint256 public fee;
    address public dao;
    mapping(address => bool) public fNFTWhitelist;
    mapping(address => Order[]) public orders;
    mapping(address => uint256) public totalEthInEscrow;
    mapping(address => mapping(address => uint256)) public totalFNFTInEscrow;

    constructor(uint256 _fee, address _dao) {
        if (_fee > 1000) revert FeeTooHigh();
        if (_dao == address(0)) revert InvalidAddress();
        fee = _fee; //1000 = 10%
        dao = _dao;
    }

    function postBuyOrder(
        address _fNFT,
        uint256 _amount,
        uint256 _price
    ) external payable {
        if (_amount * _price != msg.value) revert EthAmountDifferent();

        orders[_fNFT].push(Order(OrderType.buy, msg.sender, _amount, _price, block.number));
        totalEthInEscrow[msg.sender] += msg.value;

        emit BuyOrderPosted(_fNFT, orders[_fNFT].length - 1, msg.sender, _amount, _price);
    }

    function postSellOrder(
        address _fNFT,
        uint256 _amount,
        uint256 _price
    ) external {
        if (_amount > IERC20(_fNFT).balanceOf(msg.sender)) revert NotEnoughFNFT();

        orders[_fNFT].push(Order(OrderType.sell, msg.sender, _amount, _price, block.number));
        totalFNFTInEscrow[msg.sender][_fNFT] += _amount;

        IERC20(_fNFT).safeTransferFrom(msg.sender, address(this), _amount);

        emit SellOrderPosted(_fNFT, orders[_fNFT].length - 1, msg.sender, _amount, _price);
    }

    function removeBuyOrder(address _fNFT, uint256 _oid) external {
        Order memory order = orders[_fNFT][_oid];
        if (msg.sender != order.host) revert OnlyOrderHost();
        if (order.orderType != OrderType.buy) revert WrongOrderType();
        if (totalEthInEscrow[msg.sender] < order.amount * order.price) revert NotEnoughBalance();

        totalEthInEscrow[msg.sender] -= order.amount * order.price;
        delete orders[_fNFT][_oid];

        _safeTransferETH(msg.sender, order.amount * order.price);

        emit BuyOrderRemoved(_fNFT, _oid, msg.sender);
    }

    function removeSellOrder(address _fNFT, uint256 _oid) external {
        Order memory order = orders[_fNFT][_oid];
        if (msg.sender != order.host) revert OnlyOrderHost();
        if (order.orderType != OrderType.sell) revert WrongOrderType();
        if (totalFNFTInEscrow[msg.sender][_fNFT] < order.amount) revert NotEnoughBalance();

        totalFNFTInEscrow[msg.sender][_fNFT] -= order.amount;
        delete orders[_fNFT][_oid];

        IERC20(_fNFT).safeTransferFrom(address(this), msg.sender, order.amount);

        emit SellOrderRemoved(_fNFT, _oid, msg.sender);
    }

    function buy(
        address _fNFT,
        uint256 _oid,
        uint256 _amount
    ) external payable {
        Order storage order = orders[_fNFT][_oid];

        if (_amount * order.price < msg.value) revert NotEnoughPayment();
        if (order.orderType != OrderType.sell) revert WrongOrderType();
        if (order.amount < _amount) revert NotEnoughSupply();

        order.amount -= _amount;
        totalFNFTInEscrow[order.host][_fNFT] -= _amount;

        uint256 tax = getTax(msg.value);

        if (tax != 0) {
            _safeTransferETH(dao, tax);
        }

        _safeTransferETH(order.host, msg.value - tax);
        IERC20(_fNFT).safeTransferFrom(address(this), msg.sender, _amount);

        emit BuyOrderFulfilled(_fNFT, _oid, msg.sender, order.host, _amount);
    }

    function sell(
        address _fNFT,
        uint256 _oid,
        uint256 _amount
    ) external {
        Order storage order = orders[_fNFT][_oid];

        if (_amount < IERC20(_fNFT).balanceOf(msg.sender)) revert NotEnoughPayment();
        if (order.orderType != OrderType.buy) revert WrongOrderType();
        if (order.amount < _amount) revert NotEnoughSupply();

        uint256 totalCost = _amount * order.price;
        uint256 tax = getTax(totalCost);

        order.amount -= _amount;
        totalEthInEscrow[order.host] -= totalCost;

        if (tax != 0) {
            _safeTransferETH(dao, tax);
        }
        _safeTransferETH(msg.sender, totalCost - tax);

        IERC20(_fNFT).safeTransferFrom(address(this), order.host, _amount);

        emit SellOrderFulfilled(_fNFT, _oid, order.host, msg.sender, _amount);
    }

    //Helper functions

    function getTax(uint256 _amount) private view returns (uint256) {
        return (_amount * fee) / 10000;
    }

    //Managerial functions

    function changeFee(uint256 _fee) external onlyOwner {
        if (_fee > 1000) revert FeeTooHigh();

        emit FeeChanged(fee, _fee);
        fee = _fee;
    }

    function changeDao(address _dao) external onlyOwner {
        if (_dao == address(0)) revert InvalidAddress();

        emit DaoChanged(dao, _dao);
        dao = _dao;
    }

    //Helper functions

    function _safeTransferETH(address to, uint256 value) private {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) revert TxFailed();
    }
}
