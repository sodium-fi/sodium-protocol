require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-chai-matchers");
require("hardhat-contract-sizer");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 37500,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNET_URL,
      },
      accounts: {
        mnemonic: process.env.DEPLOYMENT_MNEMONIC,
      },
      chainId: 1,
    },
    goerli: {
      url: process.env.GOERLI_URL,
      accounts: [process.env.TEST_PRIVATE_KEY],
    },
    mainnet: {
      url: process.env.MAINNET_URL,
      accounts: {
        mnemonic: process.env.DEPLOYMENT_MNEMONIC,
      },
    },
  },
  gasReporter: {
    currency: "USD",
    coinmarketcap: process.env.COIN_MARKET_CAP_KEY,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY,
  },
};
