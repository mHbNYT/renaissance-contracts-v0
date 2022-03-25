
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./InitializedProxy.sol";
import "./Settings.sol";
import "./IFO.sol";

contract IFOFactory is Ownable, Pausable {
  /// @notice the number of ERC721 vaults
  uint256 public vaultCount;

  /// @notice the mapping of vault number to vault contract
  mapping(uint256 => address) public vaults;

  /// @notice a settings contract controlled by governance
  address public immutable settings;
  /// @notice the TokenVault logic contract
  address public immutable logic;

  mapping(address => address) public ifo;

  event IfoCreated(
    address _fNFT,
    uint256 _amountForSale,
    uint256 _price,
    uint256 _cap,
    bool _allowWhitelisting
  );

  error AlreadyExists();

  constructor(address _settings) {
    settings = _settings;
    logic = address(new IFO(_settings));
  }

  /// @notice the function to create a ifo
  /// @param _fNFT the desired name of the vault
  /// @param _amountForSale the desired sumbol of the vault
  /// @param _price the ERC721 token address fo the NFT
  /// @param _cap the uint256 ID of the token
  /// @param _allowWhitelisting the initial price of the NFT
  function create(
    address _fNFT,
    uint256 _amountForSale,
    uint256 _price,
    uint256 _cap,
    bool _allowWhitelisting
  ) external whenNotPaused {
      if ( ifo[_fNFT] == address(0) ) revert AlreadyExists();

    bytes memory _initializationCalldata =
      abi.encodeWithSignature(
        "initialize(address,uint256,uint256,uint256,bool)",
        _fNFT,
        _amountForSale,
        _price,
        _cap,
        _allowWhitelisting
    );

    address _ifo = address(
      new InitializedProxy(
        logic,
        _initializationCalldata
      )
    );

    ifo[_fNFT] = _ifo;

    emit IfoCreated(
        _fNFT,
        _amountForSale,
        _price,
        _cap,
        _allowWhitelisting
    );
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }
}