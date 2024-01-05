const hre = require("hardhat");

async function main() {
  const YunGouCreateFactory = await hre.ethers.getContractFactory(
    "YunGouCreateFactory"
  );

  const factory = await YunGouCreateFactory.deploy();

  await factory.deployed();

  console.log(`YunGouCreateFactory deployed to ${factory.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YunGouCreateFactory_G.js --network goerli

// npx hardhat verify --network goerli 0x9B69a0a54D1114Ce792A2AaB8b9B6d363F44D6de

// npx hardhat verify --network goerli 0x9fb1aE38F7f832696C36dad1D7a5444B5d6073CE
