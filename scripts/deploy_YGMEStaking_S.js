const hre = require("hardhat");

async function main() {
  const YgmeStaking = await hre.ethers.getContractFactory("YgmeStaking");
  // address _ygme, address _ygio, address _withdrawSigner
  const ygmeStaking = await YgmeStaking.deploy(
    "0x709B78B36b7208f668A3823c1d1992C0805E4f4d",
    "0x5Bb9dE881543594D17a7Df91D62459024c4EEf02",
    "0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA"
  );

  await ygmeStaking.deployed();

  console.log(`YgmeMint deployed to ${ygmeStaking.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YGMEStaking_S.js --network sepolia

// npx hardhat verify --network sepolia 0x55D24F88D87A12845261a2059Ba3e0dF31214100 0x709B78B36b7208f668A3823c1d1992C0805E4f4d 0x5Bb9dE881543594D17a7Df91D62459024c4EEf02 0x5ab85B15e0ED0009A8AA606cb07809230fC16eaA
