const hre = require("hardhat");

async function main() {
  const YunGouNFTLaunchFactory = await hre.ethers.getContractFactory(
    "YunGouNFTLaunchFactory"
  );

  // address _impl, address _feeAccount, address _owner
  const ygNFTLaunchFactory = await YunGouNFTLaunchFactory.deploy(
    "0x55d37aF918f20126123E610C973CA8a9838423c8",
    "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2",
    "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2"
  );

  await ygNFTLaunchFactory.deployed();

  console.log(
    `YunGouNFTLaunchFactory deployed to ${ygNFTLaunchFactory.address}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YunGouNFTLaunchFactory_S.js --network sepolia

// npx hardhat verify --network sepolia 0xA8175500C3CFE066fBf2f27E6c300561039A0f86 0x55d37aF918f20126123E610C973CA8a9838423c8 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2
