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
  paths: {
    sources: "./src/contracts",
    artifacts: "./build/artifacts",
    cache: "./build/cache",
  },
};

export default config;
