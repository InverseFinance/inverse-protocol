require("@nomiclabs/hardhat-waffle");
require('dotenv').config()

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 11386168
      }
    }
  },
  solidity: {
    compilers: [ {
      version: "0.7.3"
    } ],
  },
};

