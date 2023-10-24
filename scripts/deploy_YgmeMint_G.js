const hre = require("hardhat");

async function main() {
  const YgmeMint = await hre.ethers.getContractFactory("YgmeMint");

  const ygmeMint = await YgmeMint.deploy();

  await ygmeMint.deployed();

  console.log(`YgmeMint deployed to ${ygmeMint.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YgmeMint_G.js --network goerli

// npx hardhat verify --network goerli 0x0Fa4640F99f876D78Fc964AFE0DD6649e7C23c4f 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2
