pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FNftERC20 is ERC20 {
    address public createdBy;
    address public fractionalizer;
    address public nft;
    uint32[] public tokenIds;    

    constructor(address _nft, address _creator, string _name, string _symbol) ERC20(_name, _symbol) {
        createdBy = _creator;
        fractionalizer = msg.sender;
        nft = _nft;
    }

    function mint(uint _amount, address _account, uint _tokenId) external {
        require(msg.sender == fractionalizer, "Only fractionalizer");
        tokenIds.push(_tokenId);
        _mint(_account, _amount);
    }
}