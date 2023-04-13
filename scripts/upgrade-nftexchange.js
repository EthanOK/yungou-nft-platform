// scripts/upgrade-nftexchange.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const ExchangeV2 = await ethers.getContractFactory("BoxV2");
  const box = await upgrades.upgradeProxy(BOX_ADDRESS, BoxV2);
  console.log("Box upgraded");
}

main();
