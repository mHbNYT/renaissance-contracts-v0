import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts, ethers} = hre;
  const {get} = deployments;

  const {deployer} = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);

  /** SET PRICE ORACLE IN FNFTSettings */

  // 1. get proxy controller
  const proxyControllerInfo = await get('MultiProxyController');
  const proxyController = new ethers.Contract(
    proxyControllerInfo.address,
    proxyControllerInfo.abi,
    signer
  );

  // 1. get price oracle proxy address from controller
  const priceOracleAddress = (await proxyController.proxyMap('PriceOracle'))[1];


  // 2. get fnftSettings proxy address from controller
  const fnftSettingsAbi = (await get('FNFTSettings')).abi; // get abi of impl contract
  const fnftSettingsAddress = (await proxyController.proxyMap('FNFTSettings'))[1];
  const fnftSettings = new ethers.Contract(
    fnftSettingsAddress,
    fnftSettingsAbi,
    signer
  );

  // 3. set price oracle address in FNFTSettings
  await fnftSettings.setPriceOracle(priceOracleAddress);

};
func.tags = ['main', 'local', 'seed'];
export default func;