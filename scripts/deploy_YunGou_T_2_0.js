const { ethers, upgrades } = require("hardhat");

async function main() {
  const YunGou = await ethers.getContractFactory("YunGou");
  const proxy = await upgrades.deployProxy(YunGou, [
    "0x7F4acD90047b121Ef8479ADC56F2379C0d359f70",
    "0xa002d00E2Db3Aa0a8a3f0bD23Affda03a694D06A",
  ]);
  await proxy.deployed();
  console.log("Proxy deployed to:", proxy.address);
}

main();

// npx hardhat run scripts/deploy_YunGou_T_2_0.js --network goerli

// npx hardhat verify --network goerli 0xb0E3773e3E02d0A1653F90345Bc8889fC820E230
