import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;

  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  const nftxVaultImpl = await deploy('NFTXVaultUpgradeable', {
    from: deployer,
    log: true,
  });

  // TODO: fee distributor, staking

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
  await deployerContract.deployNFTXVaultFactory(
    nftxVaultFactoryImpl.address,
    nftxVaultImpl.address
  );

};

func.tags = ['main', 'local', 'seed'];
export default func;