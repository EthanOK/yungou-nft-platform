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

    return { ygio, owner, ygioStaking, otherAccount };
  }

  describe("Function: stakingYGIO", function () {
    it("stakingYGIO should success", async function () {
      const { ygio, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount = utils.parseEther("200");

      expect(await ygioStaking.callStatic.stakingYGIO(amount, 30)).to.equal(
        true
      );

      let txStaking = await ygioStaking.stakingYGIO(amount, 30);

      await txStaking.wait();

      let orders = await ygioStaking.getStakingOrderIds(owner.address);
      expect(orders.length).to.equal(1);

      let stakingData = await ygioStaking.getStakingData(orders[0]);

      expect(stakingData.owner).to.equal(owner.address);
      expect(stakingData.amount).to.equal(amount);

      const ONE_CYCLE = await ygioStaking.ONE_CYCLE();

      expect(stakingData.endTime.sub(stakingData.startTime)).to.equal(
        BigNumber.from("30").mul(ONE_CYCLE)
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

    it("ERC20: insufficient allowance", async function () {
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

  describe("Function: unStakeYGIO", function () {
    it("stakingYGIO should success", async function () {
      const { otherAccount, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount = utils.parseEther("200");
      let stakeCycle = 30;

      expect(
        await ygioStaking.callStatic.stakingYGIO(amount, stakeCycle)
      ).to.equal(true);

      let txStaking = await ygioStaking.stakingYGIO(amount, stakeCycle);

      await txStaking.wait();

      let orders = await ygioStaking.getStakingOrderIds(owner.address);
      expect(orders.length).to.equal(1);
      // unStakeYGIO

      // TODO:等 30 * ONE_CYCLE0 再执行
      await delay(stakeCycle * 1000);

      // 预执行 unStakeYGIO 不改变链的状态
      expect(await ygioStaking.callStatic.unStakeYGIO(orders)).to.equal(true);

      let txUnStake = await ygioStaking.unStakeYGIO(orders);
      await txUnStake.wait();

      let orders_ = await ygioStaking.getStakingOrderIds(owner.address);
      expect(orders_.length).to.equal(0);
    });

    it("Not yet time to unStake", async function () {
      // 1: stakingYGIO
      const { otherAccount, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount = utils.parseEther("200");

      expect(await ygioStaking.callStatic.stakingYGIO(amount, 30)).to.equal(
        true
      );

      let txStaking = await ygioStaking.stakingYGIO(amount, 30);

      await txStaking.wait();

      let orders = await ygioStaking.getStakingOrderIds(owner.address);

      // unStakeYGIO
      await expect(
        ygioStaking.callStatic.unStakeYGIO(orders)
      ).to.be.revertedWith("Not yet time to unStake");
    });
    it("Invalid account", async function () {
      // 1: stakingYGIO
      const { otherAccount, owner, ygioStaking } = await loadFixture(
        deployOneYearLockFixture
      );

      let amount = utils.parseEther("200");

      expect(await ygioStaking.callStatic.stakingYGIO(amount, 30)).to.equal(
        true
      );

      let txStaking = await ygioStaking.stakingYGIO(amount, 30);

      await txStaking.wait();

      let orders = await ygioStaking.getStakingOrderIds(owner.address);

      // unStakeYGIO
      const ygioStakingA = ygioStaking.connect(otherAccount);

      await expect(
        ygioStakingA.callStatic.unStakeYGIO(orders)
      ).to.be.revertedWith("Invalid account");
    });
  });

  /*   describe("Function: unStakeYGIO", function () {
    it("stakingYGIO should success", async function () {
      //
    });
  }); */
});

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
