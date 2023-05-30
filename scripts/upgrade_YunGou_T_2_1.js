// scripts/upgrade-nftexchange.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  // const options = { initializer: 'initialize' };
  // const upgradedContract = await upgrades.upgradeProxy(proxyAddress, newContract, options);

  // const NFTYUNGOUV1 = await ethers.getContractFactory("NFTYUNGOUV1");
  // const contractA = await upgrades.forceImport(proxyAddress, NFTYUNGOUV1);
  const proxyAddress = "0xCb293B7083c08204e310F0FAeCCd546c9FAC6d5A";
  const YunGou2_1 = await ethers.getContractFactory("YunGou2_1");
  const upgrade = await upgrades.upgradeProxy(proxyAddress, YunGou2_1);
  console.log("NftExchange upgraded!");
  console.log(upgrade.address);
}

main();

// npx hardhat run scripts/upgrade_YunGou_T_2_1.js --network goerli

// npx hardhat verify --network goerli 0xCb293B7083c08204e310F0FAeCCd546c9FAC6d5A
