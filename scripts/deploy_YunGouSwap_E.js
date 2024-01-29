const hre = require("hardhat");

async function main() {
  const YunGouSwap = await hre.ethers.getContractFactory("YunGouSwap");
  // address _ygio,
  // address _usdt,
  // address _receiver,
  // address _signer
  const _ygio = "0x19C996c4E4596aADDA9b7756B34bBa614376FDd4";
  const _usdt = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
  const _receiver = "0x20B04Ce868A6FD40F7df2B89AeEFaD18873ba444";
  const _signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const yunGouSwap = await YunGouSwap.deploy(_ygio, _usdt, _receiver, _signer);

  await yunGouSwap.deployed();

  console.log(`YunGouSwap deployed to ${yunGouSwap.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YunGouSwap_E.js --network mainnet

// npx hardhat verify --network mainnet 0x8d393C25eCbB9B3059566BfC6d5c239F09EFb467 0x19C996c4E4596aADDA9b7756B34bBa614376FDd4 0xdAC17F958D2ee523a2206206994597C13D831ec7 0x20B04Ce868A6FD40F7df2B89AeEFaD18873ba444 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
