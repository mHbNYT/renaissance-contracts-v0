//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MockNFT is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("TestName", "TEST") {
        _tokenIdCounter.increment();
    }

    function mint(address _to, uint256 _id) external {
        _mint(_to, _id);
    }
}

contract NameableMockNFT is ERC721, Ownable {

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _tokenIdCounter.increment();
    }

    function mint(address _to, uint256 _id) external {
        _mint(_to, _id);
    }

}
