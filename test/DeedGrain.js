const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DeedGrain", async () => {
  let accounts;
  let deployer;
  let deedGrain;

  before(async () => {
    accounts = await ethers.getSigners();
    deployer = accounts[0];
  });

  beforeEach(async () => {
    const DeedGrain = await ethers.getContractFactory("DeedGrain");
    deedGrain = await DeedGrain.deploy("DeedGrain", "DG", "", false);
    await deedGrain.deployed();
  });

  it("Should not be able to mint DG", async () => {
    await expect(deedGrain.connect(accounts[1]).mint(deployer.address, 1)).to.be.revertedWith("");
  });

  it("Should be able to mint DG", async () => {
    await deedGrain.connect(accounts[0]).mint(deployer.address, 1);
    expect(await deedGrain.balanceOf(deployer.address, 1)).to.equal(1);
  });

  it("Should not be able to transfer DG", async () => {
    await deedGrain.mint(deployer.address, 1);
    await expect(deedGrain.connect(deployer).safeTransferFrom(deployer.address, accounts[1].address, 1, 1, ethers.utils.randomBytes(0))).to.be.revertedWith("this NFT is not allowed to be transferred");
  });

  it("Should be able to transfer DG", async () => {
    await deedGrain.mint(deployer.address, 1);
    await deedGrain.reverseTransferable();
    await deedGrain.connect(deployer).safeTransferFrom(deployer.address, accounts[1].address, 1, 1, ethers.utils.randomBytes(0));
    expect(await deedGrain.balanceOf(accounts[1].address, 1)).to.equal(1);
  });

  it("Should be able to burn DG", async () => {
    await deedGrain.mint(deployer.address, 1);
    await deedGrain.connect(deployer).burn(deployer.address, 1, 1);
    expect(await deedGrain.balanceOf(deployer.address, 1)).to.equal(0);
  });

  it("Should not be able to burn DG", async () => {
    await deedGrain.mint(deployer.address, 1);
    await expect(deedGrain.connect(accounts[1]).burn(deployer.address, 1, 1)).to.be.revertedWith("");
  });
});
