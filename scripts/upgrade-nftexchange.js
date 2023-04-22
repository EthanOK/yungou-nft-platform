// scripts/upgrade-nftexchange.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  // const options = { initializer: 'initialize' };
  // const upgradedContract = await upgrades.upgradeProxy(proxyAddress, newContract, options);
  const proxyAddress = "0x5D0C8b801d2Fd1dEEBB5aDfA89a8609becD01D83";
  const ExchangeV2 = await ethers.getContractFactory("NFTYUNGOUV1");
  const upgrade = await upgrades.upgradeProxy(proxyAddress, ExchangeV2);
  console.log("NftExchange upgraded!");
  console.log(upgrade);
}

main();
// npx hardhat run scripts/upgrade-nftexchange.js --network sepolia

// npx hardhat run scripts/upgrade-nftexchange.js --network goerli

// npx hardhat verify --network goerli 0x101C602a32cAB1B3B5dE7f5aE0E6D627f78f5F59
