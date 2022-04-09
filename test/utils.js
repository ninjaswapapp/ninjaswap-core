const { BN } = require('openzeppelin-test-helpers');
const BigNumber = require('bignumber.js');

const advanceTime = time =>
  new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: '2.0',
        method: 'evm_increaseTime',
        params: [time],
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        return resolve(result);
      },
    );
  });

const advanceBlock = () =>
  new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: '2.0',
        method: 'evm_mine',
        id: new Date().getTime(),
      },
      err => {
        if (err) {
          return reject(err);
        }
        const newBlockHash = web3.eth.getBlock('latest').hash;

        return resolve(newBlockHash);
      },
    );
  });

const getCurrentTime = async () => (await web3.eth.getBlock('latest')).timestamp;

const advanceTimeAndBlock = async time => {
  await advanceTime(time);
  await advanceBlock();

  return Promise.resolve(web3.eth.getBlock('latest'));
};

module.exports = {
    advanceTime,
    advanceBlock,
    advanceTimeAndBlock,
    getCurrentTime,
  };