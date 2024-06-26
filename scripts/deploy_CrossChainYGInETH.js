const hre = require("hardhat");

async function main() {
  await cc_main();
  // await cc_goerli();
}

async function cc_main() {
  const CrossChainYGInETH = await hre.ethers.getContractFactory(
    "CrossChainYGInETH"
  );
  const ygio = "0x19C996c4E4596aADDA9b7756B34bBa614376FDd4";

  const ygme = "0x1b489201D974D37DDd2FaF6756106a7651914A63";

  const signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const cc = await CrossChainYGInETH.deploy(ygio, ygme, signer);

  await cc.deployed();

  console.log(`CrossChainYGInETH deployed to ${cc.address}`);
}

async function cc_goerli() {
  const CrossChainYGInETH = await hre.ethers.getContractFactory(
    "CrossChainYGInETH"
  );
  const ygio = "0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab";

  const ygme = "0x28D1bC817DE02C9f105A6986eF85cB04863C3042";

  const signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const cc = await CrossChainYGInETH.deploy(ygio, ygme, signer);

  await cc.deployed();

  console.log(`CrossChainYGInETH deployed to ${cc.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_CrossChainYGInETH.js --network goerli
// npx hardhat verify --network goerli 0xB51145F42A744726f4fC27d69DF5225431C85A16 0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab 0x28D1bC817DE02C9f105A6986eF85cB04863C3042 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA

// TODO:
// 部署成功后，将 Cross合约地址 设置 为 ygme 白名单

// npx hardhat run scripts/deploy_CrossChainYGInETH.js --network mainnet
// npx hardhat verify --network mainnet 0xaB4803501d26364150a4d3Cd029b8354F6dc9f3D 0x19C996c4E4596aADDA9b7756B34bBa614376FDd4 0x1b489201D974D37DDd2FaF6756106a7651914A63 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
