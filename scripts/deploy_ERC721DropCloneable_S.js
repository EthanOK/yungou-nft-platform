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

// npx hardhat verify --network sepolia 0x55d37aF918f20126123E610C973CA8a9838423c8
