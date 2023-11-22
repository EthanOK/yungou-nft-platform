const hre = require("hardhat");

async function main() {
  await ygio_tbsc();
  //  await ygio_bsc();
}

async function ygio_tbsc() {
  const YGIO_BSC = await hre.ethers.getContractFactory("YGIOToken");

  const _owner = "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2";

  const ygio = await YGIO_BSC.deploy(_owner);

  await ygio.deployed();

  console.log(`YGIO_BSC deployed to ${ygio.address}`);
}

async function ygio_bsc() {
  const YGIO_BSC = await hre.ethers.getContractFactory("YGIOToken");

  const _owner = "0xC675897Bb91797EaeA7584F025A5533DBB13A000";

  const ygio = await YGIO_BSC.deploy(_owner);

  await ygio.deployed();

  console.log(`YGIO_BSC deployed to ${ygio.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YGIO_TBSC.js --network tbsc
// npx hardhat verify --network tbsc 0x071589C3d21CB744321EF98c55322E3b85F11c73 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2
