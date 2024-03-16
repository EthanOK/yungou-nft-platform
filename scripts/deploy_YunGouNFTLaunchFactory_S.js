const hre = require("hardhat");

async function main() {
  const YunGouNFTLaunchFactory = await hre.ethers.getContractFactory(
    "YunGouNFTLaunchFactory"
  );

  // address _impl, address _feeAccount, address _owner
  const ygNFTLaunchFactory = await YunGouNFTLaunchFactory.deploy(
    "0xf9d48aA208137A9c8363fF7b00f0ac6a7Aac5c2a",
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

//  use `Standard Json-Input` verify In Etherscan.
