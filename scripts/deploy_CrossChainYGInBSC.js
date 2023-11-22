const hre = require("hardhat");

async function main() {
  // TODO:
  // await cc_tbsc();

  await cc_bsc();
}

async function cc_tbsc() {
  const CrossChainYGInBSC = await hre.ethers.getContractFactory(
    "CrossChainYGInBSC"
  );
  const ygio = "0x0Fa4640F99f876D78Fc964AFE0DD6649e7C23c4f";

  const ygme = "0xDb6c494BE6Aae80cc042f9CDA24Ce573aD163A46";

  const signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const cc = await CrossChainYGInBSC.deploy(ygio, ygme, signer);

  await cc.deployed();

  console.log(`CrossChainYGInBSC deployed to ${cc.address}`);
}

async function cc_bsc() {
  const CrossChainYGInBSC = await hre.ethers.getContractFactory(
    "CrossChainYGInBSC"
  );
  // TODO
  const ygio = "0xa2FCACCDCf80Ab826e3Da6831dA711E7c85C6F67";

  const ygme = "0xe88e04e739EB73978E76B6A20A86643f2A0E364a";

  const signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const cc = await CrossChainYGInBSC.deploy(ygio, ygme, signer);

  await cc.deployed();

  console.log(`CrossChainYGInBSC deployed to ${cc.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_CrossChainYGInBSC.js --network tbsc

// npx hardhat verify --network tbsc 0xa47738eaa7B1daf9Bd1f438afc8CCC4661e69a3C 0x0Fa4640F99f876D78Fc964AFE0DD6649e7C23c4f 0xDb6c494BE6Aae80cc042f9CDA24Ce573aD163A46 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA

// TODO:
// 部署成功后，将 Cross合约地址 设置 为ygio和ygme 白名单

// npx hardhat run scripts/deploy_CrossChainYGInBSC.js --network bsc

// npx hardhat verify --network bsc 0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D 0xa2FCACCDCf80Ab826e3Da6831dA711E7c85C6F67 0xe88e04e739EB73978E76B6A20A86643f2A0E364a 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
