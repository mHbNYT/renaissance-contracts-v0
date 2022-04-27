//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

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

    event FNFTCreated(
        address indexed token, 
        address FNFT, 
<<<<<<< HEAD
        uint256 id, 
=======
        address creator, 
>>>>>>> 6d26e18846b1f053877f43c7a561b3f3e6fbaf48
        
        uint256 price,         
        string name, 
        string symbol
    );

    constructor(address _fnftSettings) {
        settings = _fnftSettings;
        logic = address(new FNFT(_fnftSettings));
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

        address fnft = address(new InitializedProxy(logic, _initializationCalldata));

        bytes32 fnftId = getFNFTId(_nft, _tokenId);
        
<<<<<<< HEAD
        emit FNFTCreated(_nft, fnft, _tokenId, _listPrice, _name, _symbol);
=======
        emit FNFTCreated(_nft, fnft, msg.sender, _listPrice, _name, _symbol);
>>>>>>> 6d26e18846b1f053877f43c7a561b3f3e6fbaf48

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
