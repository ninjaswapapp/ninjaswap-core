const BigNumber = require('bignumber.js')
const BN = require('bn.js')
const { balance, ether, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const chai = require('chai')
chai.use(require('chai-as-promised'))
chai.use(require('chai-bignumber')(BigNumber))
const { constants, utils } = require("ethers");

const expect = chai.expect

const privateKEy = '0x0559c996f08fffbc702cbe496e955ce12d6a8d9f74fce8976346d8cca4a7dc7e';
const addresss = '0x4ed7dCD152e5292e21197dae8Ee9E5C77ea48270';

const CalimerContract = artifacts.require("NinjaBountyAirdropBank");
const MockERC20 = artifacts.require('MockERC20')

const createSignature = (recipient,amount,privKey) => {
    const message = web3.utils.soliditySha3(
        { t: 'address', v: recipient },
        { t: 'uint256', v: amount }
    ).toString('hex');
    const { signature } = web3.eth.accounts.sign(
        message,
        privKey
    );
    return { signature, recipient, amount };
};
contract('NinjaBountyAirdropBank', (accounts) => {
    const { toWei } = web3.utils;
    const { fromWei } = web3.utils;
    let calimerContract;
    const Owner = accounts[0]
    const userOne = accounts[1]
    const userTwo = accounts[2]
    const userThree = accounts[3]
    const authenticator = addresss;
    const INIT_BALANCE = toWei('30000');
    const user_balance = toWei('5000');
    const fake_balance = toWei('15000');
    let Ninja;
    let Volt;
    before(async () => {
        Ninja = await MockERC20.new('Ninja Token', 'NINJA', INIT_BALANCE, {from: Owner})
        Volt = await MockERC20.new('Volter Token', 'VOLT', INIT_BALANCE, {from: Owner})
        calimerContract = await CalimerContract.new(authenticator,Ninja.address, INIT_BALANCE ,{ from: Owner })
        await Ninja.mint(calimerContract.address ,INIT_BALANCE , {  from: Owner,} )
        await Volt.mint(calimerContract.address ,INIT_BALANCE , {  from: Owner,} )
    })
    it('airdrop Contract should initialize correctly', async () => {
        let round = await calimerContract.getRoundById(0);
        expect(round[3].toString()).to.be.equal(INIT_BALANCE.toString());
        expect(round[1].toString()).to.be.equal("NinjaSwap Round # 2");
    })
    it('successfully claimed airdrop', async () => {
        var { recipient, amount, signature } = createSignature(
            userOne,
            user_balance,
            privateKEy);

        const result= await calimerContract.claimReward(user_balance , 0 , signature ,{ from: userOne });
        const event = result.logs[0].args
        let round = await calimerContract.getRoundById(0);
        expect(event.user).to.be.equal(userOne)
        expect(round[4].toString()).to.be.equal(user_balance.toString())
    })
    it('reject claimed airdrop', async () => {
        var { recipient, amount, signature } = createSignature(
            userOne,
            user_balance,
            privateKEy);

        await expectRevert(
            calimerContract.claimReward(fake_balance , 0 , signature ,{ from: userOne }),
            'wrong signature');
    })
    it('successfully claimed volt airdrop', async () => {
        await calimerContract.addNewRound(INIT_BALANCE , 'volt airdrop' , Volt.address ,{ from: Owner });
        var { recipient, amount, signature } = createSignature(
            userOne,
            user_balance,
            privateKEy);

        const result= await calimerContract.claimReward(user_balance , 1 , signature ,{ from: userOne });
        const event = result.logs[0].args
        let round = await calimerContract.getRoundById(1);
        expect(event.user).to.be.equal(userOne)
        expect(round[4].toString()).to.be.equal(user_balance.toString())
    })
})
