// hardhat.config.js
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");
require("dotenv").config();

const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY;
const BSC_TESTNET_URL = process.env.BSC_TESTNET_URL;
const BSC_MAINNET_URL = process.env.BSC_MAINNET_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

module.exports = {
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    bscTestnet: {
      url: BSC_TESTNET_URL || "",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 97,
      gasPrice: 20000000000,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 31337,
      gasPrice: 20000000000,
    },
    bscMainnet: {
      url: BSC_MAINNET_URL || "",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 56,
      gasPrice: 500000000,
      gasLimit: 200000,   
    },
  },
  etherscan: {
    apiKey: BSCSCAN_API_KEY,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};