import "@nomiclabs/hardhat-waffle";
import {node_url, accounts, getChainId, apiKey} from './utils/network';
// import {node_url, accounts, getChainId} from ;

export default {
  solidity: {
    compilers: [
      {
        version: '0.6.12',
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999,
          },
        },
      },
      {
        version: '0.7.5',
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999,
          },
        },
      },
      {
        version: '0.8.9',
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999,
          },
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: node_url('localhost'),
      accounts: accounts(),
    },
    aurora: {
      url: node_url('aurora'),
      chainId: getChainId('aurora'),
      accounts: accounts('aurora'),
      live: true,
      saveDeployments: true,
      tags: ['aurora'],
      gasPrice: 2000000000,
      gas: 8000000,
    },
    aurora_testnet: {
      url: node_url('aurora_testnet'),
      chainId: getChainId('aurora_testnet'),
      accounts: accounts('aurora_testnet'),
      live: true,
      saveDeployments: true,
      tags: ['aurora_testnet'],
      gasPrice: 2000000000,
      gas: 8000000,
    }
  },
  etherscan : {
    // Your API key for Etherscan
    // Obtain one at httpsL//etherscan.io/
    apiKey: apiKey('aurora')
  }
};