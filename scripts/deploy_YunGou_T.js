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

// npx hardhat run scripts/deploy_YunGou.js --network goerli

// npx hardhat verify --network goerli 0xCb293B7083c08204e310F0FAeCCd546c9FAC6d5A
