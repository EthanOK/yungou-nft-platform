const hre = require("hardhat");

async function main() {
  const YunGouMarketRegistry = await hre.ethers.getContractFactory(
    "MarketRegistry"
  );

  const marketRegistry = await YunGouMarketRegistry.deploy();

  await marketRegistry.deployed();

  console.log(`YunGouMarketRegistry deployed to ${marketRegistry.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_MarketRegistry_T.js --network goerli

// npx hardhat verify --network tbsc 0x0000C882F269B5Ef434679cd0F50189AbF19cB27

// npx hardhat verify --network bsc 0x0000C882F269B5Ef434679cd0F50189AbF19cB27

// npx hardhat verify --network mainnet 0x0000C882F269B5Ef434679cd0F50189AbF19cB27
