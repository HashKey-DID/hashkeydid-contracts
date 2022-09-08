const { expect } = require("chai");
const { ethers } = require('hardhat');


describe("DidGrain", async() => {
    let accounts;
    let deployer;
    let didGrain;
    before(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
    })
    beforeEach(async () => {
        const DidGrain = await ethers.getContractFactory("DeedGrain");
        didGrain = await DidGrain.deploy("DidGrain","DG","",false);
        await didGrain.deployed();
    })
    it("Should be not able to mint DG", async () => {
        await expect(didGrain.connect(accounts[1]).mint(deployer.address,1)).to.be.revertedWith("");
    })
    it("Should be able to mint DG", async () => {
        await didGrain.connect(accounts[0]).mint(deployer.address,1);
        expect(await didGrain.balanceOf(deployer.address,1)).to.equal(1);
    })
    it("Should be not able to transfer DG", async () => {
        await didGrain.mint(deployer.address,1);
        await expect(didGrain.connect(deployer).safeTransferFrom(deployer.address,accounts[1].address,1,1,ethers.utils.randomBytes(0))).to.be.revertedWith(
            'this NFT is not allowed to be transferred'
            );
    })
    it("Should be able to transfer DG", async () => {
        await didGrain.mint(deployer.address,1);
        await didGrain.reverseTransferable();
        await didGrain.connect(deployer).safeTransferFrom(deployer.address,accounts[1].address,1,1,ethers.utils.randomBytes(0));
        expect(await didGrain.balanceOf(accounts[1].address,1)).to.equal(1);
    })
    it("Should be able to burn DG", async () => {
        await didGrain.mint(deployer.address,1);
        await didGrain.connect(deployer).burn(deployer.address,1,1);
        expect(await didGrain.balanceOf(deployer.address,1)).to.equal(0);
    })
    it("Should be not able to burn DG", async () => {
        await didGrain.mint(deployer.address,1);
        await expect(didGrain.connect(accounts[1]).burn(deployer.address,1,1)).to.be.revertedWith("");
    })
});