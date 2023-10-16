const hre = require("hardhat");

async function main() {
  const YGIO_BSC = await hre.ethers.getContractFactory("YGIO_BSC");

  const _slippageAccount = "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2";

  const ygio = await YGIO_BSC.deploy(_slippageAccount);

  await ygio.deployed();

  console.log(`YGIO_BSC deployed to ${ygio.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YGIO_TBSC.js --network tbsc

// npx hardhat verify --network tbsc 0x0Fa4640F99f876D78Fc964AFE0DD6649e7C23c4f 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2
