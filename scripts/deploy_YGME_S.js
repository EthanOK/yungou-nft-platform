const hre = require("hardhat");

async function main() {
  const YunGouMember = await hre.ethers.getContractFactory("YunGouMember");
  // address pay,
  // address reward,
  // address newOwner,
  // string memory _baseUri
  const pay = "0x590dcA422b660071F978E5A69851A18529B45415";
  const reward = "0x5Bb9dE881543594D17a7Df91D62459024c4EEf02";
  const newOwner = "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2";
  const _baseUri = "ipfs://QmPAcZGzXzcrCfs399nASK2SJGEByjZr3atBpGML4vzfj1";

  const yunGouMember = await YunGouMember.deploy(
    pay,
    reward,
    newOwner,
    _baseUri
  );

  await yunGouMember.deployed();

  console.log(`YunGouMember deployed to ${yunGouMember.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_YGME_S.js --network sepolia

// npx hardhat verify --network sepolia 0x709B78B36b7208f668A3823c1d1992C0805E4f4d 0x590dcA422b660071F978E5A69851A18529B45415 0x5Bb9dE881543594D17a7Df91D62459024c4EEf02 0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2 ipfs://QmPAcZGzXzcrCfs399nASK2SJGEByjZr3atBpGML4vzfj1
