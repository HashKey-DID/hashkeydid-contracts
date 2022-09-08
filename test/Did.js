const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");
const { Contract } = require("hardhat/internal/hardhat-network/stack-traces/model");

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
        storageProxy = await StorageProxy.deploy(didV1.address,deployer.address,"0x");
        await storageProxy.deployed();
        didV1.attach(storageProxy.address);
        await didV1.initialize("DivV1","Did","",deployer.address);
    });
    it("Should be equal to admin address", async () => {
        await didV1.connect(accounts[1]).claim("jack.key");
        expect(await didV1.tokenId2Did(1)).to.equal("jack.key");
    });

    it("Should be able to issue DG", async () => {
        const HDNode = ethers.utils.HDNode.fromMnemonic(process.env.mnemonic);
        const pri = HDNode.derivePath(`m/44'/60'/0'/0/0`).privateKey;
        const signingKey = new ethers.utils.SigningKey(pri);
        const signature = signingKey.signDigest(ethers.utils.solidityKeccak256(["address"],[deployer.address]));
        let sig = ethers.utils.joinSignature(signature);
        if (sig.substring(sig.length-2,sig.length) === "1c") {
            sig = sig.substring(0,sig.length-2) + "01";
        }
        if (sig.substring(sig.length-2,sig.length) === "1b") {
            sig = sig.substring(0,sig.length-2) + "00";
        }
        await didV1.connect(deployer).setSigner(deployer.address);
        const tx = await didV1.connect(deployer).issueDG("test","ts","test/",sig,true);
        const receipt = await tx.wait();
        const IssueDgEvent = receipt.events?.filter((x) => {return x.event == "IssueDG"});
        const DgAddr = IssueDgEvent[0].args[1];
        const DeedGrain = await ethers.getContractFactory("DeedGrain");
        const dg = DeedGrain.attach(DgAddr);
        expect(await dg.uri(1)).to.equal("test/1");
    })
})
