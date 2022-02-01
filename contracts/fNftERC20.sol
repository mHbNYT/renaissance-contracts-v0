//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract FNftERC20 is ERC20, ERC721Holder {
    bool private lock;
    address public createdBy;
    address public fractionalizer;
    address public nft;
    uint[] public tokenIds;
    struct Bid {
        uint256 amount;
        address tokenId;
        bool accepted;
        address token;
    }
    mapping public bid(address => Bid);

    constructor(address _nft, address _creator, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        createdBy = _creator;
        fractionalizer = msg.sender;
        nft = _nft;
    }

    function mint(uint _amount, address _account, uint _tokenId) external {
        require(msg.sender == fractionalizer, "Only fractionalizer");
        tokenIds.push(_tokenId);
        _mint(_account, _amount);
    }

    function withdrawl() {
        
    }

    function buy(uint tokenId) external {
        storage bid = bid[msg.sender].accepted;
        require(bid.accepted);
        ERC20(bid.token).transferFrom(msg.sender, address(this), bid.amount);
        ERC721(nft).transfer(msg.sender, bid.tokenId);
        locked = true;
    }

    // function liquidate(uint _tokenId) onlyFractionalizer {
    //    create a ratio of the tokenId to the total amount of NFTs associated with the FNFT
    //    multiply that ratio by the total supply of the NFT
    //    burn that amount.
    //    transfer that tokenId back to the treasury
    // }
}

interface IFNFTERC20 {

    function mint(uint _amount, address, blah);

    function withdrawl();

}