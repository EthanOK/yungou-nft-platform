const hre = require("hardhat");

async function main() {
  const YunGouAggregatorV2 = await hre.ethers.getContractFactory(
    "YunGouAggregatorV2"
  );
  // TODO: _marketRegistry: 0x3a9E49D9110Ce9f22338f86674A4d7B453BEe554 0x0000C882F269B5Ef434679cd0F50189AbF19cB27
  const marketRegistry = "0x3a9E49D9110Ce9f22338f86674A4d7B453BEe554";

  const aggregators = await YunGouAggregatorV2.deploy(marketRegistry);

  await aggregators.deployed();

  console.log(`YunGouAggregators deployed to ${aggregators.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_AggregatorV2_T.js --network goerli
// npx hardhat verify --network goerli 0x47d61786dE9135AF0031f38A9E1475DB5702344D 0x3a9E49D9110Ce9f22338f86674A4d7B453BEe554

// npx hardhat verify --network tbsc 0x0000081ab39f161829d49D402ac0BdD2e54e9F09 0x0000C882F269B5Ef434679cd0F50189AbF19cB27
