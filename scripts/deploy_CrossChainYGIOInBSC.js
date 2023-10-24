const hre = require("hardhat");

async function main() {
  const CrossChainYGIOInBSC = await hre.ethers.getContractFactory(
    "CrossChainYGIOInBSC"
  );
  const ygio = "0x0Fa4640F99f876D78Fc964AFE0DD6649e7C23c4f";
  const signer = "0x53188E798f2657576c9de8905478F46ac2f24b67";

  const cc = await CrossChainYGIOInBSC.deploy(ygio, signer);

  await cc.deployed();

  console.log(`CrossChainYGIOInBSC deployed to ${cc.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_CrossChainYGIOInBSC.js --network tbsc

// npx hardhat verify --network tbsc 0x6AAf3B8a8E42BeDc226e2d1F166Dfdc22d4b5182 0x0Fa4640F99f876D78Fc964AFE0DD6649e7C23c4f 0x53188E798f2657576c9de8905478F46ac2f24b67
