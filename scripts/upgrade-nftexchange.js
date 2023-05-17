// scripts/upgrade-nftexchange.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  // const options = { initializer: 'initialize' };
  // const upgradedContract = await upgrades.upgradeProxy(proxyAddress, newContract, options);
  const proxyAddress = "0x5D0C8b801d2Fd1dEEBB5aDfA89a8609becD01D83";

  const NFTYUNGOUV1 = await ethers.getContractFactory("NFTYUNGOUV1");

  const contractA = await upgrades.forceImport(proxyAddress, NFTYUNGOUV1);

  const NFTYUNGOUV1_0_2 = await ethers.getContractFactory("NFTYUNGOUV1_0_2");
  const upgrade = await upgrades.upgradeProxy(proxyAddress, NFTYUNGOUV1_0_2);
  console.log("NftExchange upgraded!");
  console.log(upgrade.address);
}

main();
// npx hardhat run scripts/upgrade-nftexchange.js --network sepolia

// npx hardhat run scripts/upgrade-nftexchange.js --network goerli

// npx hardhat verify --network goerli 0x34f035B226cfdFDFA925ec0DfE00d59A2de40A49
