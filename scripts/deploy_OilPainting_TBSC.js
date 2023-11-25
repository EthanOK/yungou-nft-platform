const hre = require("hardhat");

async function main() {
  await op_tbsc();
  // await ygio_bsc();
}

async function op_tbsc() {
  const OP = await hre.ethers.getContractFactory("OilPainting");

  const _projectPartys = ["0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2"];

  const _incomeDistributions = [10000];

  const _baseURI =
    "ipfs://bafybeidlx7d65ftmtvk2v6lzxmii2nnkvmlcqj2hmlcvpug7viv36ljqty/";

  const op = await OP.deploy(_projectPartys, _incomeDistributions, _baseURI);

  await op.deployed();

  console.log(`OilPainting_BSC deployed to ${op.address}`);
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

// npx hardhat run scripts/deploy_OilPainting_TBSC.js --network tbsc
// npx hardhat verify --constructor-args  paras/oilPainting.js --network tbsc 0x82DefF76B72A135173a7f1adA69Aad019d7AC5c3
