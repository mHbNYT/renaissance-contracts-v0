import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  
  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();

  const IFOSettings = await get('IFOSettings')

  await deploy('IFOFactory', {
    from: deployer,
    args: [IFOSettings.address],
    log: true,
  });

};
export default func;