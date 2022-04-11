import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {testnets, zeroAddress} from '../utils/constants';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  
  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await hre.getChainId();

  // get WETH address
  let { WETH } = await getNamedAccounts();
  if (testnets.includes(chainId)) {
    const mockWETH = await get('WETH');
    WETH = mockWETH.address;
  }

  await deploy('FNFTSettings', {
    from: deployer,
    args: [WETH, zeroAddress], // set price oracle address after deployment
    log: true,
  });

};
export default func;