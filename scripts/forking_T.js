const { ethers } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

// start: npx hardhat node (forking)
// npx hardhat run scripts/forking_T.js --network localhost

async function main() {
  const myAccount = "0x6278a1e803a76796a3a1f7f6344fe874ebfe94b2";

  // await setBalance();

  // await transferUSDTBinanceToReceiver(myAccount);

  await transferETHBinanceToReceiver(myAccount);
}

main();

async function setBalance() {
  await helpers.setBalance(
    "0x6278A1E803A76796a3A1f7F6344fE874ebfe94B2",
    ethers.utils.parseEther("100000000000")
  );

  await helpers.setBalance(
    "0xCcC991EA497647a90Ec6630eD72607d20F87C079",
    ethers.utils.parseEther("100000000000")
  );
}
async function transferETHBinanceToReceiver(receiver) {
  const accountBinance = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503";

  const impersonatedSigner = await ethers.getSigner(accountBinance);

  const tx = await impersonatedSigner.sendTransaction({
    to: receiver,
    value: ethers.utils.parseEther("100"), // 1 ether
  });

  await tx.wait();
}
async function transferUSDTBinanceToReceiver(receiver) {
  //Binance: Binance-Peg Tokens
  const accountBinance = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503";
  const USDTContract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
  const USDTAbi = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function balanceOf(address) view returns (uint)",
    "function transfer(address to, uint amount)",
  ];
  const signer = await getSigner_ImpersonatingAccounts(accountBinance);

  const USDT = new ethers.Contract(USDTContract, USDTAbi, signer);

  const balanceOfBinance = await USDT.balanceOf(accountBinance);

  console.log(balanceOfBinance);

  const tx = await USDT.transfer(receiver, balanceOfBinance);

  await tx.wait();

  console.log(await USDT.balanceOf(receiver));
}
async function getSigner_ImpersonatingAccounts(account) {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [account],
  });
  const signer = ethers.provider.getSigner(account);
  return signer;
}
