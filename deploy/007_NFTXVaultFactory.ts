import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import { ethers } from 'ethers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;

  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  const nftxVaultImpl = await deploy('NFTXVaultUpgradeable', {
    from: deployer,
    log: true,
  });

  const nftxFeeDistributorImpl = await deploy('NFTXSimpleFeeDistributor', {
    from: deployer,
    log: true,
  });

  // deploy implementation contract
  const nftxVaultFactoryImpl = await deploy('NFTXVaultFactoryUpgradeable', {
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

  const treasury = "0x511fefe374e9cb50baf1e3f2e076c94b3ef8b03b";
  const nftxFeeDistributorTx = await deployerContract.deployNFTXSimpleFeeDistributor(
    nftxFeeDistributorImpl.address,
    treasury
  );
  const nftxFeeDistributorReceipt = await nftxFeeDistributorTx.wait();
  const event = nftxFeeDistributorReceipt.events.find((event: ethers.Event) => event.event === "NftxSimpleFeeDistributorDeployed");
  const [nftxFeeDistributorAddress,] = event.args;

  await deployerContract.deployNFTXVaultFactory(
    nftxVaultFactoryImpl.address,
    nftxVaultImpl.address,
    nftxFeeDistributorAddress
  );
};

func.tags = ['main', 'local', 'seed'];
export default func;