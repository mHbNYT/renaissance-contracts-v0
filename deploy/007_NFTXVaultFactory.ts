import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { ethers } from 'ethers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;

  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  // deploy implementation contract
  const nftxVaultImpl = await deploy('NFTXVaultUpgradeable', {
    from: deployer,
    log: true,
  });

  const nftxLPStakingImpl = await deploy('NFTXLPStaking', {
    from: deployer,
    log: true,
  });

  const nftxFeeDistributorImpl = await deploy('NFTXSimpleFeeDistributor', {
    from: deployer,
    log: true,
  });

  const nftxVaultFactoryImpl = await deploy('NFTXVaultFactoryUpgradeable', {
    from: deployer,
    log: true,
  });

  const stakingTokenProviderImpl = await deploy('StakingTokenProvider', {
    from: deployer,
    log: true,
  });

  // deploy proxy contract
  const deployerInfo = await get('Deployer')
  const deployerContract = new ethers.Contract(
    deployerInfo.address,
    deployerInfo.abi,
    signer
  );

  const stakingTokenProviderTx = await deployerContract.deployStakingTokenProvider(
    stakingTokenProviderImpl.address,
    "0xc66F594268041dB60507F00703b152492fb176E7", // Trisolaris factory
    "0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB", // WETH
    "x" // default prefix
  );
  const stakingTokenProviderReceipt = await stakingTokenProviderTx.wait();
  let event = stakingTokenProviderReceipt.events.find((event: ethers.Event) => event.event === "StakingTokenProviderDeployed");
  const [stakingTokenProviderAddress,] = event.args;

  const nftxLPStakingTx = await deployerContract.deployNFTXLPStaking(
    nftxLPStakingImpl.address,
    stakingTokenProviderAddress
  );
  const nftxLPStakingReceipt = await nftxLPStakingTx.wait();
  event = nftxLPStakingReceipt.events.find((event: ethers.Event) => event.event === "NftxLPStakingDeployed");
  const [nftxLPStakingAddress,] = event.args;

  const treasury = "0x511fefe374e9cb50baf1e3f2e076c94b3ef8b03b";
  const nftxFeeDistributorTx = await deployerContract.deployNFTXSimpleFeeDistributor(
    nftxFeeDistributorImpl.address,
    nftxLPStakingAddress,
    treasury
  );
  const nftxFeeDistributorReceipt = await nftxFeeDistributorTx.wait();
  event = nftxFeeDistributorReceipt.events.find((event: ethers.Event) => event.event === "NftxSimpleFeeDistributorDeployed");
  const [nftxFeeDistributorAddress,] = event.args;

  await deployerContract.deployNFTXVaultFactory(
    nftxVaultFactoryImpl.address,
    nftxVaultImpl.address,
    nftxFeeDistributorAddress
  );
};

func.tags = ['main', 'local', 'seed'];
export default func;