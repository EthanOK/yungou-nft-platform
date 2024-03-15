const hre = require("hardhat");

async function main() {
  const YunGouSwap = await hre.ethers.getContractFactory("YunGouSwap");

  const _ygio = "0x5Bb9dE881543594D17a7Df91D62459024c4EEf02";
  const _usdt = "0x590dcA422b660071F978E5A69851A18529B45415";
  const _receiver = "0x7F4acD90047b121Ef8479ADC56F2379C0d359f70";
  const _signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const yunGouSwap = await YunGouSwap.deploy(_ygio, _usdt, _receiver, _signer);

  await yunGouSwap.deployed();

  console.log(`YunGouSwap deployed to ${yunGouSwap.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YunGouSwap_S.js --network sepolia

// npx hardhat verify --network sepolia 0x0f9D0bBfe093d4cf57ae1281ccF1A42c9F66fe38 0x5Bb9dE881543594D17a7Df91D62459024c4EEf02 0x590dcA422b660071F978E5A69851A18529B45415 0x7F4acD90047b121Ef8479ADC56F2379C0d359f70 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
