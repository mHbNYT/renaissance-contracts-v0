//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVaultManager {
    function fnftSingleFactory() external view returns (address);
    function fnftCollectionFactory() external view returns (address);
    function excludedFromFees(address) external view returns (bool);
    function feeDistributor() external view returns (address);
    function __VaultManager_init(
        address _weth,
        address _ifoFactory,
        address _priceOracle
    ) external;
    function WETH() external view returns (address);
    function priceOracle() external view returns (address);
    function ifoFactory() external view returns (address);
    function zapContract() external view returns (address);
    function feeReceiver() external view returns (address payable);
    function togglePaused() external;
    function addVault(address _fnft) external returns (uint256 vaultId);
    function setPriceOracle(address _priceOracle) external;
    function setFeeDistributor(address _feeDistributor) external;
    function setFeeExclusion(address _address, bool _excluded) external;
    function setFeeReceiver(address payable _feeReceiver) external;
    function setZapContract(address _zapContract) external;
    function setFNFTCollectionFactory(address _fnftCollectionFactory) external;
    function setFNFTSingleFactory(address _fnftCollectionFactory) external;
    function vault(uint256 vaultId) external view returns (address);
    function vaults(uint256) external view returns (address);
    function numVaults() external view returns (uint);

    event PriceOracleUpdated(address _old, address _new);
    event FeeReceiverUpdated(address _old, address _new);
    event ZapContractUpdated(address _old, address _new);
    event FNFTCollectionFactoryUpdated(address _old, address _new);
    event FNFTSingleFactoryUpdated(address _old, address _new);
    event VaultSet(uint256 _vaultId, address _fnft);
    event FeeDistributorUpdated(address oldDistributor, address newDistributor);
    event FeeExclusionUpdated(address target, bool excluded);

    error MaxAuctionLengthOutOfBounds();
    error MinAuctionLengthOutOfBounds();
    error FeeTooHigh();
    error MinBidIncreaseOutOfBounds();
    error MinVotePercentageTooHigh();
    error MaxReserveFactorTooLow();
    error MinReserveFactorTooHigh();
    error ZeroAddressDisallowed();
    error MultiplierTooLow();
    error OnlyFactory();
}
