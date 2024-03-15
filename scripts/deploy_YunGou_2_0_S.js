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

// npx hardhat run scripts/deploy_YunGou_2_0_S.js --network sepolia

// npx hardhat verify --network sepolia 0xaa0a5D4AA1ff88c71A3bE4983844E604Af1923EC
