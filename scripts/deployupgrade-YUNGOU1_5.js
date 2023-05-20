// scripts/create-box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const YUNGOU_1_5 = await ethers.getContractFactory("YUNGOU_1_5");
  const proxy = await upgrades.deployProxy(YUNGOU_1_5, [
    "0x7F4acD90047b121Ef8479ADC56F2379C0d359f70",
    "0xa002d00E2Db3Aa0a8a3f0bD23Affda03a694D06A",
  ]);
  await proxy.deployed();
  console.log("Proxy deployed to:", proxy.address);
}

main();

// npx hardhat run scripts/deployupgrade-YUNGOU1_5.js --network sepolia
// npx hardhat verify --network sepolia 0x0cbb378181adb971287df89f1f2a9e9cf62af72c

// npx hardhat run scripts/deployupgrade-YUNGOU1_5.js --network goerli

// npx hardhat verify --network goerli 0x413E7C5Cc2cD3380b7C32159A1933de7c70f4735

// npx hardhat run scripts/deployupgrade-YUNGOU1_5.js --network mainnet
// npx hardhat verify --network mainnet 0x93B161cE690251f629CEaE8cA1F69ab29e3EB77B
