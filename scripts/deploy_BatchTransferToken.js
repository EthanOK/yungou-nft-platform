const hre = require("hardhat");

async function main() {
  await op_g();
}

async function op_g() {
  const BatchTransferToken = await hre.ethers.getContractFactory(
    "BatchTransferToken"
  );

  // console.log(BatchTransferToken.bytecode); // init code 不包含构造函数的参数
  console.log(BatchTransferToken.getDeployTransaction()); // 包含构造函数的参数

  // return;

  const batch = await BatchTransferToken.deploy();

  await batch.deployed();

  console.log(`BatchTransferToken deployed to ${batch.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_BatchTransferToken.js --network goerli

// npx hardhat verify --network goerli 0xe4F8432beAC41e01DfA3A11E26E79266e74Dc988

// npx hardhat run scripts/deploy_BatchTransferToken.js --network mainnet
// npx hardhat verify --network mainnet 0xC384bB0A50Ae21Ea36b3d9D9864593915100D939

// npx hardhat run scripts/deploy_BatchTransferToken.js --network sepolia
// npx hardhat verify --network sepolia 0x6e7f9fCcAdFD34689A9542534c25475B5FFB7282
