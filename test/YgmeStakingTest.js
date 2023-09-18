const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
describe("YgmeStaking", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, signer] = await ethers.getSigners();

    const YGIO = await ethers.getContractFactory(
      "contracts/YunGouPlatformCoin/YGIO.sol:YGIO"
    );
    const ygio = await YGIO.deploy([
      signer.address,
      signer.address,
      owner.address,
      signer.address,
      signer.address,
    ]);
    await ygio.deployed();

    const YGME = await ethers.getContractFactory(
      "contracts/YunGouPlatformCoin/YGME.sol:YGME"
    );
    const ygme = await YGME.deploy(signer.address, signer.address);
    await ygme.deployed();

    const YgmeStaking = await ethers.getContractFactory("YgmeStaking");

    const adresssygio = ygio.address;
    const adresssygme = ygme.address;

    const ygmes = await YgmeStaking.deploy(
      adresssygme,
      adresssygio,
      signer.address
    );
    await ygmes.deployed();

    let amount = await ygio.balanceOf(owner.address);

    let tx = await ygio.transfer(ygmes.address, amount);
    await tx.wait();

    return { ygio, ygme, ygmes, owner, otherAccount, signer };
  }
  describe("withdrawERC20", function () {
    it("ygio and ygme is true", async function () {
      const { ygio, ygme, ygmes, owner, otherAccount, signer } =
        await loadFixture(deployOneYearLockFixture);

      expect(await ygmes.ygme()).to.equal(ygme.address);

      expect(await ygmes.ygio()).to.equal(ygio.address);

      expect(await ygmes.getWithdrawSigner()).to.equal(signer.address);
    });

    it("signature is true", async function () {
      let { ygio, ygme, ygmes, owner, otherAccount, signer } =
        await loadFixture(deployOneYearLockFixture);

      expect(await ygmes.getWithdrawSigner()).to.equal(signer.address);

      let [encodedData, hashData] = await getEncodedDataAndhashData(
        1,
        otherAccount.address,
        "20000000000000000000000000"
      );

      const signature = await getSignature(hashData, signer);
      ygmes = ygmes.connect(otherAccount);

      console.log("balanceOf(ygmes):" + (await ygio.balanceOf(ygmes.address)));
      console.log(
        "balanceOf(otherAccount):" +
          (await ygio.balanceOf(otherAccount.address))
      );

      let tx = await ygmes.withdrawERC20(encodedData, signature);
      await tx.wait();
      
      console.log("withdrawERC20:");
      console.log(
        "balanceOf(otherAccount):" +
          (await ygio.balanceOf(otherAccount.address))
      );

      console.log("balanceOf(ygmes):" + (await ygio.balanceOf(ygmes.address)));
    });
  });
});

async function getEncodedDataAndhashData(orderId, account, amount) {
  const type = ["uint256", "address", "uint256"];
  const args = [orderId, account, amount];

  const encodedData = ethers.utils.defaultAbiCoder.encode(type, args);

  const hashData = ethers.utils.keccak256(encodedData);

  return [encodedData, hashData];
}
async function getSignature(hashData, signer) {
  let binaryData_ = ethers.utils.arrayify(hashData);

  let signPromise_ = signer.signMessage(binaryData_);
  return signPromise_;
}
