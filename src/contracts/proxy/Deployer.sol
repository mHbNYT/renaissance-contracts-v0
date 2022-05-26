//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../FNFTSettings.sol";
import "../FNFTFactory.sol";
import "../IFOSettings.sol";
import "../IFOFactory.sol";
import "../PriceOracle.sol";
import "../NFTXVaultFactoryUpgradeable.sol";
import "./AdminUpgradeabilityProxy.sol";
import "./IMultiProxyController.sol";
import "../interfaces/IOwnable.sol";
import "../interfaces/IIFOSettings.sol";

contract Deployer is Ownable {
    event FNFTSettingsProxyDeployed(
        address indexed _logic,
        address _creator
    );

    event IFOSettingsProxyDeployed(
        address indexed _logic,
        address _creator
    );


    event FNFTFactoryProxyDeployed(
        address indexed _logic,
        address _creator
    );

    event IFOFactoryProxyDeployed(
        address indexed _logic,
        address _creator
    );

    event PriceOracleProxyDeployed(
        address indexed _logic,
        address _creator
    );

    event NftxVaultFactoryDeployed(
        address indexed _logic,
        address _creator
    );

    error NoController();

    IMultiProxyController public proxyController;

    bytes32 constant public IFO_SETTINGS = bytes32(0x49464f53657474696e6773000000000000000000000000000000000000000000);
    bytes32 constant public FNFT_SETTINGS = bytes32(0x464e465453657474696e67730000000000000000000000000000000000000000);
    bytes32 constant public FNFT_FACTORY = bytes32(0x464e4654466163746f7279000000000000000000000000000000000000000000);
    bytes32 constant public IFO_FACTORY = bytes32(0x49464f466163746f727900000000000000000000000000000000000000000000);
    bytes32 constant public PRICE_ORACLE = bytes32(0x50726963654f7261636c65000000000000000000000000000000000000000000);
    bytes32 constant public NFTX_VAULT_FACTORY = bytes32(0x4e4654585661756c74466163746f72795570677261646561626c650000000000);

    // Gov

    function setProxyController(address _controller) external onlyOwner {
        proxyController = IMultiProxyController(_controller);
    }

    // Logic

    /// @notice the function to deploy IFOSettings
    /// @param _logic the implementation
    function deployIFOSettings(address _logic) external onlyOwner returns (address ifoSettings) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFOSettings.initialize.selector
        );

        ifoSettings = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IIFOSettings(ifoSettings).setFeeReceiver(payable(msg.sender));
        IOwnable(ifoSettings).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(IFO_SETTINGS, ifoSettings);

        emit IFOSettingsProxyDeployed(ifoSettings, msg.sender);
    }

    /// @notice the function to deploy FNFTSettings
    /// @param _logic the implementation
    /// @param _weth variable needed for FNFTSettings
    /// @param _ifoFactory variable needed for FNFTSettings
    function deployFNFTSettings(
        address _logic,
        address _weth,
        address _ifoFactory
    ) external onlyOwner returns (address fnftSettings) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTSettings.initialize.selector,
            _weth,
            _ifoFactory
        );

        fnftSettings = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IFNFTSettings(fnftSettings).setFeeReceiver(payable(msg.sender));
        IOwnable(fnftSettings).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(FNFT_SETTINGS, fnftSettings);

        emit FNFTSettingsProxyDeployed(fnftSettings, msg.sender);
    }

    /// @notice the function to deploy FNFTFactory
    /// @param _logic the implementation
    /// @param _fnftSettings variable needed for FNFTFactory
    function deployFNFTFactory(
        address _logic,
        address _fnftSettings
    ) external onlyOwner returns (address fnftFactory) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTFactory.initialize.selector,
            _fnftSettings
        );

        fnftFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IOwnable(fnftFactory).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(FNFT_FACTORY, fnftFactory);

        emit FNFTFactoryProxyDeployed(fnftFactory, msg.sender);
    }

    /// @notice the function to deploy IFOFactory
    /// @param _logic the implementation
    /// @param _ifoSettings variable needed for IFOFactory
    function deployIFOFactory(
        address _logic,
        address _ifoSettings
    ) external onlyOwner returns (address ifoFactory) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFOFactory.initialize.selector,
            _ifoSettings
        );

        ifoFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IOwnable(ifoFactory).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(IFO_FACTORY, ifoFactory);

        emit IFOFactoryProxyDeployed(ifoFactory, msg.sender);
    }

    /// @notice the function to deploy PriceOracle
    /// @param _logic the implementation
    function deployPriceOracle(address _logic) external onlyOwner returns (address priceOracle) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            PriceOracle.initialize.selector
        );

        priceOracle = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IOwnable(priceOracle).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(PRICE_ORACLE, priceOracle);

        emit PriceOracleProxyDeployed(priceOracle, msg.sender);
    }

    /// @notice the function to deploy NFTXVaultFactoryUpgradeable
    /// @param _logic the implementation
    function deployNFTXVaultFactory(address _logic, address nftxVaultImpl) external onlyOwner returns (address nftxVaultFactory) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            NFTXVaultFactoryUpgradeable.__NFTXVaultFactory_init.selector,
            nftxVaultImpl,
            // address _feeDistributor
            address(0x000000000000000000000000000000000000dEaD)
        );

        nftxVaultFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        IOwnable(nftxVaultFactory).transferOwnership(msg.sender);

        proxyController.deployerUpdateProxy(NFTX_VAULT_FACTORY, nftxVaultFactory);

        emit NftxVaultFactoryDeployed(nftxVaultFactory, msg.sender);
    }
}
