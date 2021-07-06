const BN = require('bn.js');
const Web3 = require('web3')
const { constants, utils } = require("ethers");
const web3 = new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:7545'))
module.exports = async(txInfo) => {
    const tx = await web3.eth.getTransaction(txInfo.tx);
    const gasCost = tx.gasPrice * txInfo.receipt.gasUsed; 
    return new BN(gasCost);
}