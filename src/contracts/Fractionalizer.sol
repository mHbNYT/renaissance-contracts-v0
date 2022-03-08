//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

// contract Fractionalizer is Ownable, ERC721Holder {
//     bool private isLocked;

//     event Fractionalized(address _nft, uint _tokenId);

//     mapping(address => address) public nftToFnft;

//     // step 1. approve your nft to this contract
//     // step 2. call fractionalize

//     function fractionalize(address _nft, uint _tokenId) public returns(address NFNT) {
//         address newFNFT = new fNFT(...args);
//         ERC721(nft).transferFrom(msg.sender, fNFTaddress, tokenId);
//         //if fNFT not in NftToFnft
//             //trnasfer ownership from _nft owner to fNFT-ERC20
//             //mint fNFT-ERC20 to the nft owner
//         //if fNFT in NftToFnft
//             //trnasfer ownership from _nft owner to fNFT-ERC20
//             //mint new fNFT-ERC20 to the nft owner

//         emit Fractionalized(_nft, _tokenId);
//     }
// }