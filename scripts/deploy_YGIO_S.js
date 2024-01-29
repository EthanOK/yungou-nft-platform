const hre = require("hardhat");

async function main() {
  await ygio();
}

async function ygio() {
  const YGIO_BSC = await hre.ethers.getContractFactory("YGIOToken");

  const _owner = "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2";

  const _cc = "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2";

  const ygio = await YGIO_BSC.deploy(_owner, _cc);

  await ygio.deployed();

  console.log(`YGIO deployed to ${ygio.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YGIO_S.js --network sepolia
// npx hardhat verify --network sepolia 0x5Bb9dE881543594D17a7Df91D62459024c4EEf02 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2
