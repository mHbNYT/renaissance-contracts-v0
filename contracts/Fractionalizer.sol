pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Fractionalizer is Ownable {
    event Fractionalized(address _nft, uint _tokenId);

    mapping(address => address) public nftToFnft;

    function fractionalize(address _nft, uint _tokenId) public returns(address) {
        //if fNFT not in NftToFnft
            //trnasfer ownership from _nft owner to fNFT-ERC20
            //mint fNFT-ERC20 to the nft owner
        //if fNFT in NftToFnft
            //trnasfer ownership from _nft owner to fNFT-ERC20
            //mint new fNFT-ERC20 to the nft owner

        emit Fractionalized(_nft, _tokenId);
    }
}