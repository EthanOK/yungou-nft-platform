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

    const balance = await ygio.balanceOf(owner.address);

    let tx = await ygio.approve(ygioStaking.address, balance.div(2));
    await tx.wait();

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

      let txStaking = await ygioStaking.stakingYGIO(amount, 30);

      await txStaking.wait();

      let orders = await ygioStaking.getStakingOrderIds(owner.address);
      expect(orders.length).to.equal(1);

      expect(await ygioStaking.callStatic.stakingYGIO(amount, 30)).to.equal(
        true
      );
    });

    it("Invalid _amount", async function () {
      const { ygio, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount0 = utils.parseEther("100");

      await expect(
        ygioStaking.callStatic.stakingYGIO(amount0, 30)
      ).to.be.revertedWith("Invalid _amount");
    });

    it("Invalid stake time", async function () {
      const { ygio, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount1 = utils.parseEther("200");

      await expect(
        ygioStaking.callStatic.stakingYGIO(amount1, 40)
      ).to.be.revertedWith("Invalid stake time");
    });

    it("Insufficient balance", async function () {
      const { ygio, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount1 = utils.parseEther("11000");

      await expect(
        ygioStaking.callStatic.stakingYGIO(amount1, 30)
      ).to.be.revertedWith("Insufficient balance");
    });

    it("Insufficient balance", async function () {
      const { ygio, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount1 = utils.parseEther("6000");

      await expect(
        ygioStaking.callStatic.stakingYGIO(amount1, 30)
      ).to.be.revertedWith("ERC20: insufficient allowance");
    });
    //
  });
});
