//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../FNFTSettings.sol";
import "../FNFTFactory.sol";
import "../IFOSettings.sol";
import "../IFOFactory.sol";
import "../PriceOracle.sol";
import "./AdminUpgradeabilityProxy.sol";

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

    /// @notice the function to deploy IFOSettings    
    /// @param _logic the implementation
    function deployIFOSettings(address _logic) external onlyOwner returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTFactory.initialize.selector            
        );

        address fnftFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
        emit FNFTFactoryProxyDeployed(fnftFactory, msg.sender);
                
        return address(fnftFactory);
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
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTSettings.initialize.selector,
            _weth,
            _ifoFactory
        );

        address fnftFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
        emit FNFTFactoryProxyDeployed(fnftFactory, msg.sender);
                
        return address(fnftFactory);
    }

    /// @notice the function to deploy FNFTFactory
    /// @param _logic the implementation
    /// @param _fnftSettings variable needed for FNFTFactory
    function deployFNFTFactory(
        address _logic,
        address _fnftSettings
    ) external onlyOwner returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTFactory.initialize.selector,
            _fnftSettings
        );

        address fnftFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
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
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFOFactory.initialize.selector,
            _ifoSettings
        );

        address ifoFactory = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
        emit IFOFactoryProxyDeployed(ifoFactory, msg.sender);
                
        return address(ifoFactory);
    }

    /// @notice the function to deploy PriceOracle
    /// @param _logic the implementation    
    function deployPriceOracle(address _logic) external onlyOwner returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            PriceOracle.initialize.selector            
        );

        address priceOracle = address(new AdminUpgradeabilityProxy(_logic, msg.sender, _initializationCalldata));
        
        emit IFOFactoryProxyDeployed(priceOracle, msg.sender);
                
        return address(priceOracle);
    }
}
