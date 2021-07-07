import "@nomiclabs/hardhat-waffle"
import 'hardhat-deploy'

export default {
  solidity: {
    version: '0.8.0',
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: 'istanbul',
    },
  },
  networks: {
    bscTest: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545/',
      accounts: [process.env.PRIVATE_KEY]
    },
    bscMain: {
      url: 'https://bsc-dataseed.binance.org/',
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
