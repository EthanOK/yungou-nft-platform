const hre = require("hardhat");

async function main() {
  await op_g();
}

async function op_g() {
  const GMCQ = await hre.ethers.getContractFactory("GoodMorningChongqing");

  const _projectPartys = [
    "0xba889CC23789002C01777a8C012B9721296dFF9e",
    "0xc6F35c2D93ee1c88F335875b5e1EaCF80b559079",
    "0x43D62a2b6E135100018ad9dBB85D1E2dA0B97167",
  ];

  const _incomeDistributions = [6000, 3000, 1000];

  const _signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const _baseURI = "ipfs://QmYcn4grX4MzgEayrcGvL11hcT5inMmbwsZFcoMxZW3fGR/";

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

// npx hardhat run scripts/deploy_GMCQ_G.js --network sepolia
// npx hardhat verify --constructor-args paras/gmcq_g.js --network sepolia 0xe99E1D7e52cDD7C692cA86283F6138C13D091545

// npx hardhat run scripts/deploy_GMCQ_G.js --network tbsc
// npx hardhat verify --constructor-args paras/gmcq_g.js --network tbsc 0x9d89960793Af7bdbC70c1464923561cd1381fd22
