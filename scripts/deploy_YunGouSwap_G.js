const hre = require("hardhat");

async function main() {
  const YunGouSwap = await hre.ethers.getContractFactory("YunGouSwap");
  // address _ygio,
  // address _usdt,
  // address _receiver,
  // address _signer
  const _ygio = "0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab";
  const _usdt = "0x965A558b312E288F5A77F851F7685344e1e73EdF";
  const _receiver = "0x7F4acD90047b121Ef8479ADC56F2379C0d359f70";
  const _signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const yunGouSwap = await YunGouSwap.deploy(_ygio, _usdt, _receiver, _signer);

  await yunGouSwap.deployed();

  console.log(`YgmeMint deployed to ${yunGouSwap.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YunGouSwap_G.js --network goerli

// npx hardhat verify --network goerli 0x3E660EC4E318E0926583210e7D0c6B17F35A86cc 0xd042eF5cF97c902bF8F53244F4a81ec4f8E465Ab 0x965A558b312E288F5A77F851F7685344e1e73EdF 0x7F4acD90047b121Ef8479ADC56F2379C0d359f70 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
