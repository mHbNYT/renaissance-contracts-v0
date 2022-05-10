//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./IFO.sol";
import "./interfaces/IFNFT.sol";
import "./interfaces/IERC20.sol";
import "./proxy/BeaconUpgradeable.sol";
import "./proxy/BeaconProxy.sol";

contract IFOFactory is OwnableUpgradeable, PausableUpgradeable, BeaconUpgradeable {
    /// @notice the mapping of fNFT to IFO address
    mapping(address => address) public getIFO;

    event IFOCreated(
        address indexed IFO,
        address indexed FNFT,
        uint256 amountForSale,
        uint256 price,
        uint256 cap,
        uint256 duration,
        bool allowWhitelisting
    );

    error IFOExists(address nft);    

    function initialize(
        address _ifoSettings
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __BeaconUpgradeable__init(address(new IFO(_ifoSettings)));
    }

    /// @notice the function to create an IFO
    /// @param _FNFT the ERC20 token address of the FNFT
    /// @param _amountForSale the amount of FNFT for sale in IFO
    /// @param _price the price of each FNFT token
    /// @param _cap the maximum amount an account can buy
    /// @param _allowWhitelisting if IFO should be governed by whitelists
    /// @return IFO address
    function create(
        address _FNFT,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        uint256 _duration,
        bool _allowWhitelisting
    ) external whenNotPaused returns (address) {
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

        address _IFO = address(new BeaconProxy(address(this), _initializationCalldata));
        getIFO[_FNFT] = _IFO;

        IERC20(_FNFT).transferFrom(msg.sender, _IFO, IERC20(_FNFT).balanceOf(msg.sender));

        emit IFOCreated(_IFO, _FNFT, _amountForSale, _price, _cap, _duration, _allowWhitelisting);

        return _IFO;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
