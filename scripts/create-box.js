// scripts/create-box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const Box = await ethers.getContractFactory("Box");
  const proxy = await upgrades.deployProxy(Box, [42], { initializer: "store" });
  await proxy.deployed();
  console.log("Box deployed to:", proxy.address);
}

main();

// npx hardhat run scripts/create-box.js --network sepolia
