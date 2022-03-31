//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./InitializedProxy.sol";
import "./FNFTSettings.sol";
import "./FNFT.sol";

contract FNFTFactory is Ownable, Pausable {
    /// @notice a mapping of fNFT ids (see getFnftId) to the address of the fNFT contract
    mapping(bytes32 => address) public fnfts;

    /// @notice a settings contract controlled by governance
    address public immutable settings;

    /// @notice the TokenVault logic contract
    address public immutable logic;

    event FNFTCreated(address indexed token, uint256 id, uint256 price, address fNFT, bytes32 fNFTId);

    constructor(address _settings) {
        settings = _settings;
        logic = address(new FNFT(_settings));
    }

    /// @notice the function to mint a fNFT
    /// @param _name the desired name of the vault
    /// @param _symbol the desired sumbol of the vault
    /// @param _nft the ERC721 token address
    /// @param _tokenId the uint256 ID of the token
    /// @param _listPrice the initial price of the NFT
    /// @return the ID of the vault
    function mint(
        string memory _name,
        string memory _symbol,
        address _nft,
        uint256 _tokenId,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee
    ) external whenNotPaused returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSignature(
            "initialize(address,address,uint256,uint256,uint256,uint256,string,string)",
            msg.sender,
            _nft,
            _tokenId,
            _supply,
            _listPrice,
            _fee,
            _name,
            _symbol
        );

        address fNFT = address(new InitializedProxy(logic, _initializationCalldata));

        bytes32 fNFTId = getfNFTId(_nft, _tokenId);
        emit FNFTCreated(_nft, _tokenId, _listPrice, fNFT, fNFTId);

        fnfts[fNFTId] = fNFT;

        IERC721(_nft).safeTransferFrom(msg.sender, fNFT, _tokenId);
        return address(fNFT);
    }

    function getfNFTId(address nftContract, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
