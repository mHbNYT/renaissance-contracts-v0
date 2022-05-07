//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./FNFTSettings.sol";
import "./FNFT.sol";
import "./proxy/BeaconUpgradeable.sol";
import "./proxy/BeaconProxy.sol";

contract FNFTFactory is OwnableUpgradeable, PausableUpgradeable, BeaconUpgradeable {
    /// @notice a mapping of fNFT ids (see getFnftId) to the address of the fNFT contract
    mapping(bytes32 => address) public fnfts;

    event FNFTCreated(
        address indexed token, 
        address FNFT, 
        address creator, 
        
        uint256 price,         
        string name, 
        string symbol
    );
    
    function initialize(
        address _fnftSettings
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __BeaconUpgradeable__init(address(new FNFT(_fnftSettings)));
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
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFT.initialize.selector,
            msg.sender,
            _nft,
            _tokenId,
            _supply,
            _listPrice,
            _fee,
            _name,
            _symbol
        );

        address fnft = address(new BeaconProxy(address(this), _initializationCalldata));

        bytes32 fnftId = getFNFTId(_nft, _tokenId);
        
        emit FNFTCreated(_nft, fnft, msg.sender, _listPrice, _name, _symbol);

        fnfts[fnftId] = fnft;

        IERC721(_nft).safeTransferFrom(msg.sender, fnft, _tokenId);
        return address(fnft);
    }

    function getFNFTId(address nftContract, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
