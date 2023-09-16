const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { BigNumber, utils } = require("ethers");
const { expect } = require("chai");
describe("YGIOStaking", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, signer] = await ethers.getSigners();

    const YGIO_B = await ethers.getContractFactory("YGIO_B");
    const ygio = await YGIO_B.deploy(otherAccount.address);
    await ygio.deployed();

    const YGIOStaking = await ethers.getContractFactory("YGIOStaking");
    const ygioStaking = await YGIOStaking.deploy(ygio.address);
    await ygioStaking.deployed();

    return { ygio, owner, ygioStaking };
  }

  /*   describe("Deploy Contract", function () {
    it("Deploy Success", async function () {
      const { ygio, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      expect(await ygio.owner()).to.equal(owner.address);

      expect(await ygioStaking.YGIO()).to.equal(ygio.address);
    });

    // it("signature is true", async function () {});
  });
 */

  describe("Function: stakingYGIO", function () {
    it("stakingYGIO should success", async function () {
      const { ygio, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount = utils.parseEther("200");
      ygio.connect(owner);

      await ygio.approve(ygioStaking.address, amount);

      ygioStaking.connect(owner);

      await ygioStaking.stakingYGIO(amount, 30);

      let orders = await ygioStaking.getStakingOrderIds(owner.address);
      console.log(orders);
    });

    // it("signature is true", async function () {});
  });
});
