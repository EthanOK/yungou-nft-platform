const hre = require("hardhat");

async function main() {
  const MinePoolsV3 = await hre.ethers.getContractFactory("MinePoolsV3");

  const ygio = "0x0Fa4640F99f876D78Fc964AFE0DD6649e7C23c4f";
  const ygme = "0xDb6c494BE6Aae80cc042f9CDA24Ce573aD163A46";
  const lp = "0x21DEf0EeF658237579f40603164Eb86c3453ad97";
  const signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const minePoolsV3 = await MinePoolsV3.deploy(ygio, ygme, lp, signer);

  await minePoolsV3.deployed();

  console.log(`MinePoolsV3 deployed to ${minePoolsV3.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_MinePoolsV3_T.js --network tbsc

// npx hardhat verify --network tbsc 0x299Ea9a6E1691A93Fa099555DfE773676A573529 0x0Fa4640F99f876D78Fc964AFE0DD6649e7C23c4f 0xDb6c494BE6Aae80cc042f9CDA24Ce573aD163A46 0x21DEf0EeF658237579f40603164Eb86c3453ad97 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
