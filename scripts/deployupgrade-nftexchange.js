// scripts/create-box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const exchange = await ethers.getContractFactory("NftExchangeV2UpgradeableT");
  const proxy = await upgrades.deployProxy(exchange, [
    "0x6278a1e803a76796a3a1f7f6344fe874ebfe94b2",
    "0xa002d00e2db3aa0a8a3f0bd23affda03a694d06a",
    250,
  ]);
  await proxy.deployed();
  console.log("Proxy deployed to:", proxy.address);
}

main();

// npx hardhat run scripts/deployupgrade-nftexchange.js --network sepolia
// npx hardhat verify --network sepolia 0x0cbb378181adb971287df89f1f2a9e9cf62af72c

// npx hardhat run scripts/deployupgrade-nftexchange.js --network goerli

// npx hardhat verify --network goerli 0x288305149ae0Ed3C1e7704baE1F3b7d83d27F71c
