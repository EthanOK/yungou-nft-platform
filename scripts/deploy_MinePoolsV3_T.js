const hre = require("hardhat");

async function main() {
  const MinePoolsV3 = await hre.ethers.getContractFactory("MinePoolsV3");

  const ygio = "0xb06DcE9ae21c3b9163cD933E40c9EE563366b783";
  const ygme = "0xDb6c494BE6Aae80cc042f9CDA24Ce573aD163A46";
  const lp = "0x54D7fb29e79907f41B1418562E3a4FeDc49Bec90";
  const signer = "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2";

  const minePoolsV3 = await MinePoolsV3.deploy(ygio, ygme, lp, signer);

  await minePoolsV3.deployed();

  console.log(`YunGouMarketRegistry deployed to ${minePoolsV3.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_MinePoolsV3_T.js --network tbsc

// npx hardhat verify --network tbsc 0x0aA2e4180Bd10f641452F5Fd2E30CB12293E7522 0xb06DcE9ae21c3b9163cD933E40c9EE563366b783 0xDb6c494BE6Aae80cc042f9CDA24Ce573aD163A46 0x54D7fb29e79907f41B1418562E3a4FeDc49Bec90 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2
