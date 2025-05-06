const { HardhatUserConfig } = require('hardhat/config');
require('@nomicfoundation/hardhat-ethers');
require('@nomicfoundation/hardhat-chai-matchers');

/** @type HardhatUserConfig */
const config = {
  solidity: "0.8.4",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  }
};

module.exports = config;

