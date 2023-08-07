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

// npx hardhat run scripts/deploy_Aggregators_T.js --network tbsc

// npx hardhat verify --network tbsc 0xC2F44737c69fc4E1361A181A6647322C31aced34 0x0000C882F269B5Ef434679cd0F50189AbF19cB27

// npx hardhat verify --network mainnet 0x0000007eE460B0928c2119E3B9747454A10d1557 0x0000C882F269B5Ef434679cd0F50189AbF19cB27

// npx hardhat verify --network bsc 0x0000007eE460B0928c2119E3B9747454A10d1557 0x0000C882F269B5Ef434679cd0F50189AbF19cB27
