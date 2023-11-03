const { ethers, BigNumber } = require("ethers");
require("dotenv").config();

async function getSlotData() {
  const main_rpc = process.env.ALCHEMY_MAINNET_URL;

  const provider = new ethers.providers.JsonRpcProvider(main_rpc);

  const slotData = await provider.getStorageAt(
    "0x1b489201D974D37DDd2FaF6756106a7651914A63",
    7
  );
  const total_ = BigNumber.from(slotData).toNumber();
  const totalSupply = total_ - 1;
  console.log(totalSupply);
}
getSlotData();
