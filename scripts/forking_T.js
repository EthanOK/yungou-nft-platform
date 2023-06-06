const { ethers } = require("hardhat");

async function main() {
  const account = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199";

  const signer = await getSigner_ImpersonatingAccounts(account);
  const tx0 = await signer.sendTransaction({
    to: "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2",
    value: ethers.utils.parseEther("5500"),
  });
  await tx0.wait();
  const tx1 = await signer.sendTransaction({
    to: "0xCcC991EA497647a90Ec6630eD72607d20F87C079",
    value: ethers.utils.parseEther("4000"),
  });
  await tx1.wait();
}

main();

async function getSigner_ImpersonatingAccounts(account) {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [account],
  });
  const signer = ethers.provider.getSigner(account);
  return signer;
}

// start: npx hardhat node (forking)
// npx hardhat run scripts/forking_T.js --network localhost
