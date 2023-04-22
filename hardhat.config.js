require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-contract-sizer");

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
    },
  },
  networks: {
    goerli: {
      url: process.env.ALCHEMY_GOERLI_URL,
      chainId: 5,
      accounts: [process.env.ygnftowner],
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
  },
  etherscan: {
    // BSC_API_KEY ETHERSCAN_API_KEY MUMBAI_API_KEY
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
};
