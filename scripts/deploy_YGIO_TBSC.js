const hre = require("hardhat");

async function main() {
  // await ygio_tbsc();
  await ygio_bsc();
}

async function ygio_tbsc() {
  const YGIO_BSC = await hre.ethers.getContractFactory("YGIOToken");

  const _owner = "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2";

  const _cc = "0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D";

  const ygio = await YGIO_BSC.deploy(_owner, _cc);

  await ygio.deployed();

  console.log(`YGIO_BSC deployed to ${ygio.address}`);
}

async function ygio_bsc() {
  const YGIO_BSC = await hre.ethers.getContractFactory("YGIOToken");

  const _owner = "0xC675897Bb91797EaeA7584F025A5533DBB13A000";

  const _cc = "0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D";

  const ygio = await YGIO_BSC.deploy(_owner, _cc);

  await ygio.deployed();

  console.log(`YGIO_BSC deployed to ${ygio.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
// Cross Chain: 0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D

// npx hardhat run scripts/deploy_YGIO_TBSC.js --network tbsc
// npx hardhat verify --network tbsc 0x071589C3d21CB744321EF98c55322E3b85F11c73 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2 0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D

// npx hardhat run scripts/deploy_YGIO_TBSC.js --network bsc
// npx hardhat verify --network bsc 0xa2FCACCDCf80Ab826e3Da6831dA711E7c85C6F67 0xC675897Bb91797EaeA7584F025A5533DBB13A000 0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D
