// scripts/upgrade-nftexchange.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  // const options = { initializer: 'initialize' };
  // const upgradedContract = await upgrades.upgradeProxy(proxyAddress, newContract, options);

  // const NFTYUNGOUV1 = await ethers.getContractFactory("NFTYUNGOUV1");
  // const contractA = await upgrades.forceImport(proxyAddress, NFTYUNGOUV1);
  const proxyAddress = "0xb0E3773e3E02d0A1653F90345Bc8889fC820E230";
  const YunGou = await ethers.getContractFactory("YunGou");
  const upgrade = await upgrades.upgradeProxy(proxyAddress, YunGou);
  console.log("NftExchange upgraded!");
  console.log(upgrade.address);
}

main();

// npx hardhat run scripts/upgrade_YunGou_T_2_1.js --network goerli

// npx hardhat verify --network goerli 0xb0E3773e3E02d0A1653F90345Bc8889fC820E230
