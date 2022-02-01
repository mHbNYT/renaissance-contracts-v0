pragma solidity 0.8.11;

contract FNFTStakingDistributor {
    address[] public fNFTStakingPools;
    mapping(address => address) public fNFTCreator;
    mapping(address => address) public fNFTLiquidityPool;
    mapping(address => bool) public fNFTStakingActive; //maps fNFT to staking pool

    modifier onlyfNFTCreator(address _fNFT) {
        require(fNFTCreator[_fNFT] == msg.sender, "Caller must be fNFT Creator");
        _;
    }

    function distribute(uint _amount) external {
        //loop through fNFT staking pools and distribute rewards to the staking pools to get totalMC by using fNFTLiquidityPool
        
        //loop through one more time to send the right _amount to staking pools            
    }

    function createStakingPool(address _fNFT, address _fNFTLiquidityPair) external {
        //require that fNFT was fractionalized by using Renaissance fractionalizer
        //require that this is from our DAO multisig or from a fNFT that has gone through our IFO process and has enough liquidity        
    }

    function addStakingPool(address _fNFT) external onlyfNFTCreator(_fNFT) {
        
    }

    function changeStakingPool(address _fNFT) external onlyfNFTCreator(_fNFT) {

    }

    function disableStakingPool(address _fNFT) external onlyfNFTCreator(_fNFT) {

    }

    function removeStakingPool(address _fNFT) external onlyfNFTCreator(_fNFT) {

    }
    
    function updatefNFTLiquidityPool(address _fNFT, address _fNFTLiquidityPair) external onlyfNFTCreator(_fNFT) {
        //require that one of the pairs of fNFTLiquidityPair is equal to _fNFT
    }
}