const HDWalletProvider = require('truffle-hdwallet-provider');
var devC = require('./devConfig.json');
var pr_key = devC.pr_key;
var developer_account = devC.account;
var mnemonic = devC.mnemonic;
module.exports = {
  migrations_directory: "./migrations",
  contracts_build_directory: "./build/contracts",
  compilers: {
    solc: {
      version: "0.6.12",
      docker: false,
      parser: "solcjs",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: "istanbul",
      },
    },
  },
  networks: {
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
  },
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
  },
    bscMainnet: {
      network_id: "56",
      provider: () =>
        new HDWalletProvider(
          [pr_key],
          "https://bsc-dataseed1.binance.org/"
        ),
      from: developer_account,
      timeoutBlocks: 800,
    },
    bsctestnet: {
      provider: () => new HDWalletProvider(mnemonic, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,       // bsc testnet's id
      gas: 10000000,   
      gasPrice: 20000000000,     
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },
    bscTest: {
      network_id: 97,
      provider: () =>
        new HDWalletProvider(
          mnemonic,
          "https://data-seed-prebsc-2-s1.binance.org:8545/"
        ),
      from: developer_account,
      timeoutBlocks: 800,
    },
    coverage: {
      host: "0.0.0.0",
      network_id: "1002",
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 1,
    },
    docker: {
      host: "localhost",
      network_id: "1313",
      port: 8545,
      gasPrice: 1,
    },
  },
};
