const hre = require("hardhat");

async function main() {
  const CrossChainYGIOInETH = await hre.ethers.getContractFactory(
    "CrossChainYGIOInETH"
  );
  const ygio = "0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab";
  const signer = "0x53188E798f2657576c9de8905478F46ac2f24b67";

  const cc = await CrossChainYGIOInETH.deploy(ygio, signer);

  await cc.deployed();

  console.log(`CrossChainYGIOInETH deployed to ${cc.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_CrossChainYGIOInETH.js --network goerli

// npx hardhat verify --network goerli 0x2817c37eB23FC4F94f1168A94f26befa1F42FF7d 0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab 0x53188E798f2657576c9de8905478F46ac2f24b67
