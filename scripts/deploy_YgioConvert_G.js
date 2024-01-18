const hre = require("hardhat");

async function main() {
  const YgioConvert = await hre.ethers.getContractFactory("YgioConvert");
  // address _ygme,
  // address _ygmeStaking,
  // address _ygio,
  // address _signer
  const _ygme_G = "0x28D1bC817DE02C9f105A6986eF85cB04863C3042";
  const _ygmeStaking_G = "0xef6b5e06d3ed692729a01a7f471d386677943c85";
  const _ygio_G = "0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab";
  const _signer_G = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const ygioConvert = await YgioConvert.deploy(
    _ygme_G,
    _ygmeStaking_G,
    _ygio_G,
    _signer_G
  );

  await ygioConvert.deployed();

  console.log(`YgmeMint deployed to ${ygioConvert.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YgioConvert_G.js --network goerli

// npx hardhat verify --network goerli 0x6cc0e230EBC7d0D91f7BED1e8800f1c853a9F526 0x28D1bC817DE02C9f105A6986eF85cB04863C3042 0xef6b5e06d3ed692729a01a7f471d386677943c85 0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
