// scripts/upgrade-nftexchange.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  // const options = { initializer: 'initialize' };
  // const upgradedContract = await upgrades.upgradeProxy(proxyAddress, newContract, options);
  const proxyAddress = "0xB6D0c44E1590D6fF9D15200f688eeADD9A836958";
  const ExchangeV2 = await ethers.getContractFactory(
    "NftExchangeV2Upgradeable"
  );
  const upgrade = await upgrades.upgradeProxy(proxyAddress, ExchangeV2);
  console.log("NftExchange upgraded!");
  console.log(upgrade);
}

main();
// npx hardhat run scripts/upgrade-nftexchange.js --network sepolia
