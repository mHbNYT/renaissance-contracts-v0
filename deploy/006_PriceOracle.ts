import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {testnets, ETH_UNISWAP_V2_FACTORY} from '../utils/constants';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  
  const {deploy, get} = deployments;
  const {deployer} = await getNamedAccounts();
  const chainId = await hre.getChainId();

  // get WETH address
  let { WETH } = await getNamedAccounts();
  let FACTORY;
  if (testnets.includes(chainId)) {
    const mockWETH = await get('WETH');
    WETH = mockWETH.address;
    FACTORY = ETH_UNISWAP_V2_FACTORY;
  } else {
    // TODO add uniswap v2 factory addresses for production deployment
    throw new Error('No factory address defined');
  }

  await deploy('PriceOracle', {
    from: deployer,
    args: [FACTORY, WETH],
    log: true,
  });

};
func.tags = ['main', 'local', 'seed'];
export default func;