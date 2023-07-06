const hre = require("hardhat");

async function main() {
  const YunGou = await hre.ethers.getContractFactory("YunGou");

  const yungou = await YunGou.deploy();

  await yungou.deployed();

  console.log(`YunGou impls deployed to ${yungou.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YunGou_Imp.js --network goerli

// npx hardhat verify --network goerli 0x00000E14B01bffc5E55e11fF92B6d6B1156c5796

// npx hardhat verify --network mainnet 0x00000E14B01bffc5E55e11fF92B6d6B1156c5796
