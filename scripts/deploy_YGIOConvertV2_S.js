const hre = require("hardhat");

async function main() {
  const YGIOConvertV2 = await hre.ethers.getContractFactory("YGIOConvertV2");

  const _ygme = "0x709b78b36b7208f668a3823c1d1992c0805e4f4d";
  const _ygmeStaking = "0x55D24F88D87A12845261a2059Ba3e0dF31214100";
  const _ygio = "0x5Bb9dE881543594D17a7Df91D62459024c4EEf02";
  const _signer = "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA";

  const ygioConvert = await YGIOConvertV2.deploy(
    _ygme,
    _ygmeStaking,
    _ygio,
    _signer
  );

  await ygioConvert.deployed();

  console.log(`YgmeMint deployed to ${ygioConvert.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YGIOConvertV2_S.js --network sepolia

// npx hardhat verify --network sepolia 0x1A734352bC247dD0Cf0633e66F64f6A6e14376dE 0x709b78b36b7208f668a3823c1d1992c0805e4f4d 0x55D24F88D87A12845261a2059Ba3e0dF31214100 0x5Bb9dE881543594D17a7Df91D62459024c4EEf02 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
