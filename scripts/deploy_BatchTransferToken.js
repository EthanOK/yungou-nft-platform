const hre = require("hardhat");

async function main() {
  await op_g();
}

async function op_g() {
  const BatchTransferToken = await hre.ethers.getContractFactory(
    "BatchTransferToken"
  );

  const batch = await BatchTransferToken.deploy();

  await batch.deployed();

  console.log(`BatchTransferToken deployed to ${batch.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_BatchTransferToken.js --network goerli

// npx hardhat verify --network goerli 0x368FA76C8EC97482A7106277e1623048A357E019

// npx hardhat run scripts/deploy_BatchTransferToken.js --network mainnet
