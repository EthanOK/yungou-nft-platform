// scripts/create-box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const exchange = await ethers.getContractFactory("NFTYUNGOUV1");
  const proxy = await upgrades.deployProxy(exchange, [
    "0xbB12EA592dc3708600aAd80934350203f3bC3aaa",
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

// npx hardhat verify --network goerli 0xc5c7Aa5d20212Cc795F606fA859Beb8626A6c742
