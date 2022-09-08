const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DidV1", async () => {
  let accounts;
  let deployer;
  let storageProxy;

  before(async () => {
    accounts = await ethers.getSigners();
    deployer = accounts[0];
  });

  beforeEach(async () => {
    const DidV1 = await ethers.getContractFactory("DidV1");
    didV1 = await DidV1.deploy();
    await didV1.deployed();
    const StorageProxy = await ethers.getContractFactory("EternalStorageProxy");
    storageProxy = await StorageProxy.deploy(didV1.address, deployer.address, "0x");
    await storageProxy.deployed();
    didV1.attach(storageProxy.address);
    await didV1.initialize("DiDV1", "Did", "", deployer.address);
  });

  it("Should be equal to admin address", async () => {
    await didV1.connect(accounts[1]).claim("jack.key");
    expect(await didV1.tokenId2Did(1)).to.equal("jack.key");
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
    await didV1.connect(deployer).setSigner(deployer.address);
    const tx = await didV1.connect(deployer).issueDG("DeedGrain", "DG", "https://api.hashkey-qa.id/eth/api/nft/metadata/", signature, true);
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
