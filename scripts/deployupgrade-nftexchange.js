// scripts/create-box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const exchange = await ethers.getContractFactory("NFTYUNGOUV1_0_0");
  const proxy = await upgrades.deployProxy(exchange, [
    "0x20B04Ce868A6FD40F7df2B89AeEFaD18873ba444",
    "0x0dD31386ebAf3D17FE65B73D683753b83d305bbb",
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

// npx hardhat run scripts/deployupgrade-nftexchange.js --network mainnet
// npx hardhat verify --network mainnet 0x93B161cE690251f629CEaE8cA1F69ab29e3EB77B
