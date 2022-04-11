import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {testnets} from '../utils/constants';

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

  const FNFTFactory = await get('FNFTFactory');

  await deploy('PriceOracle', {
    from: deployer,
    args: [WETH, FNFTFactory.address],
    log: true,
  });

};
export default func;