const hre = require("hardhat");

async function main() {
  await op_g();
}

async function op_g() {
  const GMCQ = await hre.ethers.getContractFactory("GoodMorningChongqing");

  const _projectPartys = [
    "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2",
    "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2",
    "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2",
  ];

  const _incomeDistributions = [6000, 3000, 1000];

  const _signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const _baseURI = "ipfs://QmPqzX9tYvKaEXpSPXvXxwgZzJj5SZLCVUToUmfDQo4w61/";

  const op = await GMCQ.deploy(
    _projectPartys,
    _incomeDistributions,
    _signer,
    _baseURI
  );

  await op.deployed();

  console.log(`GMCQ deployed to ${op.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_GMCQ_G.js --network goerli
// npx hardhat verify --constructor-args paras/gmcq_g.js --network goerli 0x400df737a64adDB76d30aa0C391e9196F48f93b4
