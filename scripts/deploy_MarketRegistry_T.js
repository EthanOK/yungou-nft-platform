const hre = require("hardhat");

async function main() {
  const YunGouMarketRegistry = await hre.ethers.getContractFactory(
    "MarketRegistry"
  );

  const marketRegistry = await YunGouMarketRegistry.deploy([], []);

  await marketRegistry.deployed();

  console.log(`YunGouMarketRegistry deployed to ${marketRegistry.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_MarketRegistry_T.js --network goerli

// npx hardhat verify --network goerli 0x5D5177aa0BD5ACeb22A249703DAe840667309F5d 0x3a9E49D9110Ce9f22338f86674A4d7B453BEe554
