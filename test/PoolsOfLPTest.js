const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { BigNumber, utils } = require("ethers");
const { expect } = require("chai");

describe("YGIOStaking", function () {
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

    let txStaking = await ygioStaking.stakingYGIO(balance.div(2), 9);

    await txStaking.wait();

    return { ygio, owner, ygioStaking, otherAccount };
  }
});
