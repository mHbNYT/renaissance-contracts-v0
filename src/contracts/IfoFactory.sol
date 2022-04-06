//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./InitializedProxy.sol";
import "./IFO.sol";
import "./interfaces/IFNFT.sol";
import {console} from "../test/utils/utils.sol";

contract IFOFactory is Ownable, Pausable {
    using SafeERC20 for IERC20;

    /// @notice the mapping of fNFT to IFO address
    mapping(address => address) public getIFO;

    /// @notice a settings contract controlled by governance
    address public immutable settings;

    /// @notice the TokenVault logic contract
    address public immutable logic;

    bytes4 public constant IFO_SALT = 0xefefefef;

    event IFOCreated(
        address indexed _IFO,
        address indexed _FNFT,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        bool _allowWhitelisting
    );

    error IFOExists(address nft);

    constructor(address _ifoSettings) {
        settings = _ifoSettings;
        logic = address(new IFO(_ifoSettings));
    }

    /// @notice the function to create a ifo
    /// @param _FNFT the desired name of the vault
    /// @param _amountForSale the desired sumbol of the vault
    /// @param _price the ERC721 token address fo the NFT
    /// @param _cap the uint256 ID of the token
    /// @param _allowWhitelisting the initial price of the NFT
    function create(
        address _FNFT,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        uint256 _duration,
        bool _allowWhitelisting
    ) external whenNotPaused {
        if (getIFO[_FNFT] != address(0)) revert IFOExists(_FNFT);
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFO.initialize.selector,
            msg.sender,
            _FNFT,
            _amountForSale,
            _price,
            _cap,
            _duration,
            _allowWhitelisting
        );

        address _IFO = address(new InitializedProxy(logic, _initializationCalldata));
        getIFO[_FNFT] = _IFO;

        IERC20(_FNFT).safeTransferFrom(msg.sender, _IFO, IERC20(_FNFT).balanceOf(msg.sender));

        emit IFOCreated(_IFO, _FNFT, _amountForSale, _price, _cap, _allowWhitelisting);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
