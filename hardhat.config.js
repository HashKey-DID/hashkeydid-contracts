require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('@openzeppelin/hardhat-upgrades');

module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
        optimizer: {
            enabled: true,
            runs: 200
        }
    }
  },
  networks: {
    hardhat: {
      accounts: { mnemonic: process.env.mnemonic },
      allowUnlimitedContractSize: true,
      gas:21000000
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  },
};
