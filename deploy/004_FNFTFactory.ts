import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  
  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();

  // get settings
  const FNFTSettings = await get('FNFTSettings');

  await deploy('FNFTFactory', {
    from: deployer,
    args: [FNFTSettings.address],
    log: true,
  });

};

func.tags = ['main', 'local', 'seed'];
export default func;