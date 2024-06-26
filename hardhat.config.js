require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");
require("hardhat-storage-layout");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
      // modelChecker: {
      //   engine: "all",
      // },
    },
  },
  networks: {
    phalcon: {
      url: process.env.PHALCON_FORK_RPC,
      accounts: [
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ],
    },

    mainnet: {
      url: process.env.ALCHEMY_MAINNET_URL,
      chainId: 1,
      // YG_Publish_ETHMAIN ygnftownerETHMAIN PRIVATE_KEY
      accounts: [process.env.PRIVATE_KEY],
    },

    goerli: {
      url: process.env.ALCHEMY_GOERLI_URL,
      chainId: 5,
      accounts: [process.env.PRIVATE_KEY],
    },

    bsc: {
      url: process.env.BSC_URL,
      chainId: 56,
      // process.env.ygnftownerETHMAIN PRIVATE_KEY
      accounts: [process.env.PRIVATE_KEY],
    },

    tbsc: {
      url: process.env.TBSC_URL,
      chainId: 97,
      accounts: [process.env.PRIVATE_KEY],
    },

    mumbai: {
      url: process.env.MUMBAI_URL,
      chainId: 80001,
      accounts: [process.env.PRIVATE_KEY],
    },

    sepolia: {
      url: process.env.ALCHEMY_SEPOLIA_URL,
      chainId: 11155111,
      accounts: [process.env.PRIVATE_KEY],
    },

    hardhat: {
      forking: {
        url: process.env.ALCHEMY_MAINNET_URL,
        blockNumber: Number(process.env.FORK_STRAT_BLOCK),
      },
      mining: {
        auto: false,
        interval: [3000, 5000],
      },
    },
  },
  etherscan: {
    // BSC_API_KEY ETHERSCAN_API_KEY MUMBAI_API_KEY
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
      goerli: process.env.ETHERSCAN_API_KEY,
      sepolia: process.env.ETHERSCAN_API_KEY,
      bsc: process.env.BSC_API_KEY,
      bscTestnet: process.env.BSC_API_KEY,
      phalcon: process.env.PHALCON_ACCESSS_KEY,
    },

    customChains: [
      {
        network: "phalcon",
        chainId: 110,
        urls: {
          apiURL: process.env.PHALCON_FORK_APIURL,
          browserURL: `https://scan.phalcon.xyz/${process.env.PHALCON_FORK_ID}`,
        },
      },
    ],
  },

  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  gasReporter: {
    enabled: true,
    currency: "USDT",
    gasPrice: 1,
  },
};
