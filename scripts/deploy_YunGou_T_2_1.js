const { ethers, upgrades } = require("hardhat");

async function main() {
  const YunGou2_1 = await ethers.getContractFactory("YunGou2_1");
  const proxy = await upgrades.deployProxy(YunGou2_1, [
    "0x7F4acD90047b121Ef8479ADC56F2379C0d359f70",
    "0xa002d00E2Db3Aa0a8a3f0bD23Affda03a694D06A",
  ]);
  await proxy.deployed();
  console.log("Proxy deployed to:", proxy.address);
}

main();

// npx hardhat run scripts/deploy_YunGou_T_2_1.js --network goerli

// npx hardhat verify --network goerli 0x413E7C5Cc2cD3380b7C32159A1933de7c70f4735
