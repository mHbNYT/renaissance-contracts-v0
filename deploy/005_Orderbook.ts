import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  
  const {deploy} = deployments;
  const {deployer, DAO} = await getNamedAccounts();

  await deploy('Orderbook', {
    from: deployer,
    args: [100, DAO], // TODO populate the 1st arg with planned orderbook fee
    log: true,
  });

};
func.tags = ['main', 'local', 'seed'];
export default func;