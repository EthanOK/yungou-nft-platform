const { ethers, upgrades } = require("hardhat");

async function main() {
  const YunGou = await ethers.getContractFactory("YunGou");
  // address payable private beneficiary;
  // address private systemVerifier;
  let beneficiary = "0x20B04Ce868A6FD40F7df2B89AeEFaD18873ba444";
  let systemVerifier = "0x0dD31386ebAf3D17FE65B73D683753b83d305bbb";
  const proxy = await upgrades.deployProxy(YunGou, [
    beneficiary,
    systemVerifier,
  ]);
  await proxy.deployed();
  console.log("Proxy deployed to:", proxy.address);
}

main();

// npx hardhat run scripts/deploy_YunGou_2_0.js --network mainnet
// npx hardhat verify --network goerli 0xb0E3773e3E02d0A1653F90345Bc8889fC820E230
