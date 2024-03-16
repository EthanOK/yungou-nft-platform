const hre = require("hardhat");

async function main() {
  const ERC721DropCloneable = await hre.ethers.getContractFactory(
    "ERC721DropCloneable"
  );

  const erc721DropCloneable = await ERC721DropCloneable.deploy();

  await erc721DropCloneable.deployed();

  console.log(`ERC721DropCloneable deployed to ${erc721DropCloneable.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_ERC721DropCloneable_S.js --network sepolia

// npx hardhat verify --network sepolia 0xf9d48aA208137A9c8363fF7b00f0ac6a7Aac5c2a
