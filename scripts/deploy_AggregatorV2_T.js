const hre = require("hardhat");

async function main() {
  const YunGouAggregatorV2 = await hre.ethers.getContractFactory(
    "YunGouAggregatorV2"
  );
  // TODO: _marketRegistry:
  // 0x3a9E49D9110Ce9f22338f86674A4d7B453BEe554 goerli
  // 0x0000C882F269B5Ef434679cd0F50189AbF19cB27 tbsc
  // 0x431164d7AC5F7228f2E36D7081378eDD27Be5Ce7 sepolia
  const marketRegistry = "0x431164d7AC5F7228f2E36D7081378eDD27Be5Ce7";

  const aggregators = await YunGouAggregatorV2.deploy(marketRegistry);

  await aggregators.deployed();

  console.log(`YunGouAggregators deployed to ${aggregators.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_AggregatorV2_T.js --network goerli

// npx hardhat run scripts/deploy_AggregatorV2_T.js --network sepolia

// npx hardhat verify --network sepolia 0x596Aa28bB2ca2D29E352bC21600DB5ECe3E69797 0x431164d7AC5F7228f2E36D7081378eDD27Be5Ce7
