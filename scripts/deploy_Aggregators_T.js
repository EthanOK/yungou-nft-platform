const hre = require("hardhat");

async function main() {
  const YunGouAggregators = await hre.ethers.getContractFactory(
    "YunGouAggregators"
  );
  // TODO: _marketRegistry: 0x3a9E49D9110Ce9f22338f86674A4d7B453BEe554
  const marketRegistry = "0x0000C882F269B5Ef434679cd0F50189AbF19cB27";

  const aggregators = await YunGouAggregators.deploy(marketRegistry);

  await aggregators.deployed();

  console.log(`YunGouAggregators deployed to ${aggregators.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_Aggregators_T.js --network goerli

// npx hardhat verify --network tbsc 0x0000A8086590DD83c8bd58A787412026B86eB772 0x0000C882F269B5Ef434679cd0F50189AbF19cB27
