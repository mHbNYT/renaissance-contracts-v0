//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../FNFTSettings.sol";
import "../FNFTFactory.sol";
import "../IFOSettings.sol";
import "../IFOFactory.sol";
import "../PriceOracle.sol";
import "./AdminUpgradeabilityProxy.sol";
import "./IMultiProxyController.sol";

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

    error NoController();

    IMultiProxyController public proxyController;

    // Gov

    function setProxyController(address _controller) external onlyOwner {
        proxyController = IMultiProxyController(_controller);
    }

    // Logic

    /// @notice the function to deploy IFOSettings    
    /// @param _logic the implementation
    function deployIFOSettings(address _logic) external onlyOwner returns (address) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFOSettings.initialize.selector            
        );

        address ifoSettings = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));

        proxyController.deployerUpdateProxy("IFOSettings", ifoSettings);

        emit IFOSettingsProxyDeployed(ifoSettings, msg.sender);        
        
        return address(ifoSettings);
    }

    /// @notice the function to deploy FNFTSettings
    /// @param _logic the implementation
    /// @param _weth variable needed for FNFTSettings
    /// @param _ifoFactory variable needed for FNFTSettings
    function deployFNFTSettings(
        address _logic,
        address _weth,
        address _ifoFactory
    ) external onlyOwner returns (address) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTSettings.initialize.selector,
            _weth,
            _ifoFactory
        );

        address fnftSettings = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
        proxyController.deployerUpdateProxy("FNFTSettings", fnftSettings);

        emit FNFTSettingsProxyDeployed(fnftSettings, msg.sender);
                
        return address(fnftSettings);
    }

    /// @notice the function to deploy FNFTFactory
    /// @param _logic the implementation
    /// @param _fnftSettings variable needed for FNFTFactory
    function deployFNFTFactory(
        address _logic,
        address _fnftSettings
    ) external onlyOwner returns (address) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTFactory.initialize.selector,
            _fnftSettings
        );

        address fnftFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
        proxyController.deployerUpdateProxy("FNFTFactory", fnftFactory);

        emit FNFTFactoryProxyDeployed(fnftFactory, msg.sender);
                
        return address(fnftFactory);
    }

    /// @notice the function to deploy IFOFactory
    /// @param _logic the implementation
    /// @param _ifoSettings variable needed for IFOFactory
    function deployIFOFactory(
        address _logic,
        address _ifoSettings
    ) external onlyOwner returns (address) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFOFactory.initialize.selector,
            _ifoSettings
        );

        address ifoFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
        proxyController.deployerUpdateProxy("IFOFactory", ifoFactory);

        emit IFOFactoryProxyDeployed(ifoFactory, msg.sender);
                
        return address(ifoFactory);
    }

    /// @notice the function to deploy PriceOracle
    /// @param _logic the implementation    
    function deployPriceOracle(address _logic) external onlyOwner returns (address) {
        if (address(proxyController) == address(0)) revert NoController();

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            PriceOracle.initialize.selector            
        );

        address priceOracle = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
        proxyController.deployerUpdateProxy("PriceOracle", priceOracle);

        emit PriceOracleProxyDeployed(priceOracle, msg.sender);
                
        return address(priceOracle);
    }
}
