import hre = require("hardhat");
import {ethers} from "ethers";


async function main() {
    const didV2Factory = await hre.ethers.getContractFactory("DidV2");
    const didV2 = await didV2Factory.deploy();

    await didV2.deployed();
    const network = await hre.ethers.provider.getNetwork()
    const chainId = network.chainId;
    const accounts = await hre.ethers.getSigners();
    const deployer = accounts[0].address;
    console.log(deployer);

    await didV2.initialize("tt", "tt", "ttr", deployer);
    await didV2.setSigner("0x8A036Bb39a8B1b19Bb24271E6Bd8ffEd0BDCc513");

    const sig = signMsgForMint(deployer, chainId, 9999999999, "kasdfg.key", "0x0000000000000000000000000000000000000000", 0);

    const tx = await didV2.claim(9999999999, "kasdfg.key", "0x0000000000000000000000000000000000000000", 0, sig, "");
    const txr = await tx.wait();
    console.log(txr.gasUsed)
}

function signMsgForMint(owner: string, chainId: number, expiredTimestamp: number, did: string, token: string, amount: number): string {
    // ganache privateKey
    const signingKey = new ethers.utils.SigningKey("0x63419710ef351278f57fd2b4bd73f9266db355f50c32e36fcf0a89b0cd8fdaeb");
    //to, block.chainid, expiredTimestamp, did, token, amount
    const signature = signingKey.signDigest(ethers.utils.solidityKeccak256(
        ["address", "uint256", "uint256", "string", "address", "uint256"],
        [owner, chainId, expiredTimestamp, did, token, amount])
    );

    let sig = ethers.utils.joinSignature(signature);
    if (sig.substring(sig.length - 2, sig.length) === "1c") {
        sig = sig.substring(0, sig.length - 2) + "01";
    }
    if (sig.substring(sig.length - 2, sig.length) === "1b") {
        sig = sig.substring(0, sig.length - 2) + "00";
    }
    console.log(sig)
    return sig;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
