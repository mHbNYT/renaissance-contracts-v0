import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers} from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  console.log('entered configure')
  const {get} = hre.deployments;

  // set price oracle in FNFTsettings
  const fnftSettingsInfo = await get('FNFTSettings');
  const priceOracleInfo = await get('PriceOracle');
  const FNFTSettings = await ethers.getContractAt(
    fnftSettingsInfo.abi, 
    fnftSettingsInfo.address
  );

  await FNFTSettings.setPriceOracle(priceOracleInfo.address);

  console.log('exited configure')

};
export default func;