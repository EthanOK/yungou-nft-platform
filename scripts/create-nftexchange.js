// scripts/create-box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const exchange = await ethers.getContractFactory("NftExchangeV1Upgradeable");
  const proxy = await upgrades.deployProxy(exchange, [
    "0x6278a1e803a76796a3a1f7f6344fe874ebfe94b2",
    "0xa002d00e2db3aa0a8a3f0bd23affda03a694d06a",
    100,
  ]);
  await proxy.deployed();
  console.log("Proxy deployed to:", proxy.address);
}

main();

// npx hardhat run scripts/create-nftexchange.js --network goerli
