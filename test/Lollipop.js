const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const { ethers } = require("hardhat");
const { constants } = require("ethers");
const { expect } = require("chai");

describe("Lollipop", function () {
  async function deployFixture() {
    const [deployer, owner, feesReceiver, pair, randomWallet] =
      await ethers.getSigners();
    const Lollipop = await ethers.getContractFactory("Lollipop");
    const lollipop = await Lollipop.deploy(
      owner.address,
      "0xd77C2afeBf3dC665af07588BF798bd938968c72E",
      feesReceiver.address,
      { value: "100" }
    );

    return { lollipop, deployer, owner, feesReceiver, pair, randomWallet };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { lollipop, owner } = await loadFixture(deployFixture);
      expect(await lollipop.owner()).to.equal(owner.address);
    });
  });

  describe("Fees", function () {
    it("It should withdraf native tokens", async function () {
      const { lollipop, deployer, owner, feesReceiver, pair, randomWallet } =
        await loadFixture(deployFixture);
      await lollipop.connect(owner).initialize();
      const contractBalanceBefore = await ethers.provider.getBalance(lollipop);
      console.log("lollipop balance -> ", contractBalanceBefore);
      await lollipop.connect(owner).withdraw();
      const contractBalanceAfter = await ethers.provider.getBalance(lollipop);
      console.log("lollipop balance -> ", contractBalanceAfter);
    });

    it("Should take a sell fee", async function () {
      const { lollipop, deployer, owner, feesReceiver, pair, randomWallet } =
        await loadFixture(deployFixture);
      await lollipop.connect(owner).initialize();
      await lollipop.connect(owner).setPair(pair);
      await lollipop.transfer(randomWallet, 1000);
      await lollipop.connect(randomWallet).transfer(pair, 100);

      const pairBalance = await lollipop.balanceOf(pair);
      const contractBalance = await lollipop.balanceOf(lollipop);
      const deployerBalance = await lollipop.balanceOf(deployer);
      const randomWalletBalance = await lollipop.balanceOf(randomWallet);
      const feesReceiverBalance = await lollipop.balanceOf(feesReceiver);

      console.log("pairBalance -> ", pairBalance);
      console.log("contractBalance -> ", contractBalance);
      console.log("deployerBalance -> ", deployerBalance);
      console.log("randomWalletBalance -> ", randomWalletBalance);
      console.log("feesReceiverBalance -> ", feesReceiverBalance);

      expect(pairBalance).to.equal(95);
      expect(contractBalance).to.equal(5);
    });

    it("Should take a buy fee", async function () {
      const { lollipop, deployer, owner, feesReceiver, pair, randomWallet } =
        await loadFixture(deployFixture);
      await lollipop.connect(owner).initialize();
      await lollipop.connect(owner).setPair(pair);
      await lollipop.transfer(pair, 1000);
      await lollipop.connect(pair).transfer(randomWallet, 100);

      const pairBalance = await lollipop.balanceOf(pair);
      const contractBalance = await lollipop.balanceOf(lollipop);
      const deployerBalance = await lollipop.balanceOf(deployer);
      const randomWalletBalance = await lollipop.balanceOf(randomWallet);

      console.log("pairBalance -> ", pairBalance);
      console.log("contractBalance -> ", contractBalance);
      console.log("deployerBalance -> ", deployerBalance);
      console.log("randomWalletBalance -> ", randomWalletBalance);

      expect(pairBalance).to.equal(900);
      expect(contractBalance).to.equal(3);
    });
  });
});
