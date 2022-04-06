// https://github.com/wighawag/hardhat-deploy#2-extra-hardhatconfig-networks-options
import "dotenv/config";
import { HardhatUserConfig } from "hardhat/types";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-interface-generator";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2_000_000,
          },
        },
      },
    ],
  },
  defaultNetwork: "localhost",
  networks: {
    hardhat: {
      chainId: +process.env.AURORA_LOCAL_CHAINID!,
      accounts: {
        mnemonic: process.env.AURORA_LOCAL_PRIVATE_KEY,
      },
    },
    aurora_testnet: {
      url: process.env.AURORA_TEST_URI,
      chainId: +process.env.AURORA_TEST_CHAINID!,
      accounts: [`${process.env.AURORA_TEST_PRIVATE_KEY}`],
      timeout: 600000,
      gasPrice: 2000000000,
      gas: 8000000  
    },
    aurora_mainnet: {
      url: process.env.AURORA_MAIN_URI,
      chainId: +process.env.AURORA_MAIN_CHAINID!,
      accounts: [`${process.env.AURORA_MAIN_PRIVATE_KEY}`],
      timeout: 600000,
      gasPrice: 2000000000,
      gas: 8000000
    }
  },
  paths: {
    sources: "./src/contracts",
    artifacts: "./build/artifacts",
    cache: "./build/cache",
  },
};

export default config;
