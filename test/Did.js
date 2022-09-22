const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DidV2", async () => {
  let accounts;
  let deployer;
  let storageProxy;

  before(async () => {
    accounts = await ethers.getSigners();
    deployer = accounts[0];
  });

  beforeEach(async () => {
    const DidV2 = await ethers.getContractFactory("DidV2");
    didV2 = await DidV2.deploy();
    await didV2.deployed();
    const StorageProxy = await ethers.getContractFactory("EternalStorageProxy");
    storageProxy = await StorageProxy.deploy(didV2.address, deployer.address, "0x");
    await storageProxy.deployed();
    didV2.attach(storageProxy.address);
    await didV2.initialize("DiDV2", "Did", "", deployer.address);
    const DGFactory = await ethers.getContractFactory("DeedGrainFactory");
    dgFactory = await DGFactory.deploy();
    await dgFactory.deployed();
    await didV2.setDGFactory(dgFactory.address);
  });

  it("Should be equal to admin address", async () => {
    await didV2.connect(accounts[1]).claim("jack.key");
    expect(await didV2.tokenId2Did(1)).to.equal("jack.key");
  });

  it("Should be able to issue DG", async () => {
    //generate signature
    const HDNode = ethers.utils.HDNode.fromMnemonic(process.env.mnemonic);
    const pri = HDNode.derivePath(`m/44'/60'/0'/0/0`).privateKey;
    const signingKey = new ethers.utils.SigningKey(pri);
    const digest = signingKey.signDigest(
      ethers.utils.solidityKeccak256(["address"], [deployer.address])
    );
    let signature = ethers.utils.joinSignature(digest);
    if (signature.substring(signature.length - 2, signature.length) === "1c") {
        signature = signature.substring(0, signature.length - 2) + "01";
    }
    if (signature.substring(signature.length - 2, signature.length) === "1b") {
        signature = signature.substring(0, signature.length - 2) + "00";
    }

    //issue deedgrain
    await didV2.connect(deployer).setSigner(deployer.address);
    const tx = await didV2.connect(deployer).issueDG("DeedGrain", "DG", "https://api.hashkey-qa.id/eth/api/nft/metadata/", signature, true);
    const receipt = await tx.wait();
    const issueDGEvent = receipt.events?.filter((x) => {
      return x.event == "IssueDG";
    });
    const deedGrainAddr = issueDGEvent[0].args[1];
    const DeedGrain = await ethers.getContractFactory("DeedGrain");
    const deedGrain = DeedGrain.attach(deedGrainAddr);
    expect(await deedGrain.name()).to.equal("DeedGrain");
  });
});
