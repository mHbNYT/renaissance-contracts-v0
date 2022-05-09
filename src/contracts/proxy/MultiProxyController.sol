// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IAdminUpgradeabilityProxy.sol";

contract MultiProxyController is Ownable {
    struct Proxy {
        string name;
        IAdminUpgradeabilityProxy proxy;     
        uint index;
        bool isValue;
    }

    mapping(string => Proxy) public proxyMap;
    string[] public proxyKeys;

    address public deployer;

    event ProxyUpdated(string key, address proxy);
    event ProxyRemoved(string key);
    event ProxyAdminChanged(string key, address newAdmin);

    constructor(string[] memory _keys, address[] memory _proxies, address _deployer) Ownable() {
        deployer = _deployer;
        uint256 length = _proxies.length;
        require(_keys.length == length, "Not equal length");
        for (uint256 i; i < length; i++) {
            addProxy(_keys[i], _proxies[i]);
        } 
    }    

    // Proxy Gov

    function upgradeProxyTo(string memory key, address newImpl) public onlyOwner {
        require(proxyMap[key].isValue, "Doesn't exist");
        proxyMap[key].proxy.upgradeTo(newImpl);
    }

    function changeProxyAdmin(string memory key, address newAdmin) public onlyOwner {
        require(proxyMap[key].isValue, "Doesn't exist");
        proxyMap[key].proxy.changeAdmin(newAdmin);
        emit ProxyAdminChanged(key, newAdmin);
    }

    // MultiProxyController Gov

    function changeDeployer(address _deployer) public onlyOwner {
        deployer = _deployer;
    }

    function deployerUpdateProxy(string memory key, address proxy) public {
        require(msg.sender == deployer, "Not deployer");
        if (proxyMap[key].isValue) {
            _changeProxy(key, proxy);
        } else {
            _addProxy(key, proxy);
        }        
    }

    function _changeProxy(string memory key, address proxyAddress) private {
        require(proxyMap[key].isValue, "Doesn't exist");

        proxyMap[key].proxy = IAdminUpgradeabilityProxy(proxyAddress);
    }

    function changeProxy(string memory key, address proxyAddress) public onlyOwner {
        _changeProxy(key, proxyAddress);
    }    

    function changeProxyKey(string memory oldKey, string memory newKey) public onlyOwner {
        require(proxyMap[oldKey].isValue, "Doesn't exist");

        Proxy memory proxy = proxyMap[oldKey];

        proxyMap[newKey] = proxy;
        proxyKeys[proxy.index] = newKey;
        delete proxyMap[oldKey];
    }

    function _addProxy(string memory key, address proxyAddress) private {
        require(!proxyMap[key].isValue, "Exists");

        IAdminUpgradeabilityProxy proxyContract = IAdminUpgradeabilityProxy(proxyAddress);
        proxyKeys.push(key);
        Proxy memory newProxy = Proxy(key, proxyContract, proxyKeys.length - 1, true);        
        proxyMap[key] = newProxy;
        emit ProxyUpdated(key, proxyAddress);
    }

    function addProxy(string memory key, address proxyAddress) public onlyOwner {
        _addProxy(key, proxyAddress);
    }

    function removeProxy(string memory key) public onlyOwner {
        require(proxyMap[key].isValue, "Doesn't exist");
        string[] storage keys = proxyKeys;
        Proxy memory proxy = proxyMap[key];

        proxyMap[keys[keys.length - 1]].index = proxy.index;

        keys[proxy.index] = keys[keys.length - 1];
        keys.pop();

        delete proxyMap[key];

        emit ProxyRemoved(key);
    }

    function getName(string memory key) public view returns (string memory) {
        return proxyMap[key].name;
    }

    function getAdmin(string memory key) public view returns (address) {
        return proxyMap[key].proxy.admin();
    }

    function getImpl(string memory key) public view returns(address) {
        return proxyMap[key].proxy.implementation();
    }

    // Bulk

    function changeAllAdmins(address newAdmin) public onlyOwner {
        uint256 length = proxyKeys.length;
        for (uint256 i; i < length; ++i) {
            changeProxyAdmin(proxyKeys[i], newAdmin);
        }
    }

    function getAllProxiesInfo() public view returns (string[] memory) {
        uint256 length = proxyKeys.length;
        string[] memory proxyInfos = new string[](length);
        for (uint256 i; i < length; ++i) {
            string memory key = proxyKeys[i];
            Proxy memory _proxy = proxyMap[key];
            proxyInfos[i] = string(abi.encodePacked(key, ": ", _proxy.name));
        }
        return proxyInfos;
    }

    function getAllProxies() public view returns (address[] memory) {
        uint256 length = proxyKeys.length;
        address[] memory proxyInfos = new address[](length);
        for (uint256 i; i < length; ++i) {
            proxyInfos[i] = address(proxyMap[proxyKeys[i]].proxy);
        }
        return proxyInfos;
    }
    
    function getAllImpls() public view returns (address[] memory) {
        uint256 length = proxyKeys.length;
        address[] memory proxyInfos = new address[](length);
        for (uint256 i; i < length; ++i) {
            proxyInfos[i] = address(proxyMap[proxyKeys[i]].proxy.implementation());
        }
        return proxyInfos;
    }
}
