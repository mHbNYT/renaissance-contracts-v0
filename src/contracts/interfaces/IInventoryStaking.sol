// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./IFNFTCollectionVaultFactory.sol";

interface IInventoryStaking {
    function fnftCollectionVaultFactory() external view returns (IFNFTCollectionVaultFactory);
    function vaultXToken(uint256 vaultId) external view returns (address);
    function xTokenAddr(address baseToken) external view returns (address);
    function xTokenShareValue(uint256 vaultId) external view returns (uint256);

    function __InventoryStaking_init(address fnftCollectionVaultFactory) external;

    function deployXTokenForVault(uint256 vaultId) external;
    function receiveRewards(uint256 vaultId, uint256 amount) external returns (bool);
    function timelockMintFor(uint256 vaultId, uint256 amount, address to, uint256 timelockLength) external returns (uint256);
    function deposit(uint256 vaultId, uint256 _amount) external;
    function withdraw(uint256 vaultId, uint256 _share) external;
}