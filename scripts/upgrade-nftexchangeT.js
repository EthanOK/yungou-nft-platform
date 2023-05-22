// scripts/upgrade-nftexchange.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  // const options = { initializer: 'initialize' };
  // const upgradedContract = await upgrades.upgradeProxy(proxyAddress, newContract, options);
  const proxyAddress = "0x413E7C5Cc2cD3380b7C32159A1933de7c70f4735";

  // const NFTYUNGOUV1 = await ethers.getContractFactory("NFTYUNGOUV1");

  // const contractA = await upgrades.forceImport(proxyAddress, YUNGOU_1_5);

  const YUNGOU_1_5 = await ethers.getContractFactory("YUNGOU_1_5");
  const upgrade = await upgrades.upgradeProxy(proxyAddress, YUNGOU_1_5);
  console.log("NftExchange upgraded!");
  console.log(upgrade.address);
}

main();

// npx hardhat run scripts/upgrade-nftexchangeT.js --network goerli

// npx hardhat verify --network goerli 0x413E7C5Cc2cD3380b7C32159A1933de7c70f4735
