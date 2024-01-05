const hre = require("hardhat");

async function main() {
  const king_address = await dos_KingOfEther();
  await dos_Attack(king_address);
}

async function dos_KingOfEther() {
  const KingOfEther = await hre.ethers.getContractFactory("KingOfEther");

  const king = await KingOfEther.deploy();

  await king.deployed();

  console.log(`KingOfEther deployed to ${king.address}`);
  return king.address;
}
async function dos_Attack(king_address) {
  const Attack = await hre.ethers.getContractFactory("Attack");

  const attack = await Attack.deploy(king_address);

  await attack.deployed();

  console.log(`Attack deployed to ${attack.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy_Dos_P.js --network phalcon
// npx hardhat verify --network phalcon 0xE2b5bDE7e80f89975f7229d78aD9259b2723d11F
// npx hardhat verify --network phalcon 0xC6c5Ab5039373b0CBa7d0116d9ba7fb9831C3f42 0xE2b5bDE7e80f89975f7229d78aD9259b2723d11F
