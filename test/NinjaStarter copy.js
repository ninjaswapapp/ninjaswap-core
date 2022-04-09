// const BigNumber = require('bignumber.js')
const BN = require('bn.js')
const Web3 = require('web3')
const { constants, utils } = require("ethers");
const web3 = new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:7545'))

const { expectEvent } = require('openzeppelin-test-helpers');
const { expectRevert } = require('@openzeppelin/test-helpers');


const {
    advanceTime,
} = require('./utils');

const WeekToSeconds = 604800;
const chai = require('chai')
chai.use(require('chai-as-promised'))
// chai.use(require('chai-bignumber')(BigNumber))

const expect = chai.expect

const MockERC20 = artifacts.require('MockERC20')
const NinjaStarter = artifacts.require('NinjaStarter');

contract('NinjaStarter', (accounts) => {
    const { toWei } = web3.utils
    const { fromWei } = web3.utils
    const INIT_BALANCE = toWei('300005')
    let busd
    let offeringToken;
    let ninjaStarter;
    const Owner = accounts[0]
    const TokenOwner = accounts[1]
    const user = accounts[2];
    const tempuser = accounts[3];
    //   const Treasury2 = accounts[2]
    //   const teamTokens = accounts[3]
    //   const bountyAddress = accounts[5];
    //   const NinjaBountyAirdropBank= accounts[6];
    before(async () => {
        busd = await MockERC20.new('Binance USD', 'BUSD', INIT_BALANCE, {
            from: user,
        });
        offeringToken = await MockERC20.new('Offer token', 'OFT', toWei('5000000'), {
            from: TokenOwner,
        });

        ninjaStarter = await NinjaStarter.new(
            offeringToken.address,
            TokenOwner,
            busd.address,
            { from: Owner },
        )
        await offeringToken.transfer(ninjaStarter.address, toWei('5000000'), {
            from: TokenOwner,
        })
    })
    it('NINJA Starter Should intial correctly', async () => {
        expect(await ninjaStarter.offeringToken()).to.be.equal(offeringToken.address)
    })
    it('Buy 100  tokens with 5 BUSD', async () => {
        await busd.approve(ninjaStarter.address, constants.MaxUint256, { from: user })
        await ninjaStarter.buyWithBusd(toWei('5'), { from: user })
        expect((await ninjaStarter.totalCollectedBUSD.call()).toString()).to.be.equal(toWei('5').toString())
        expect((await ninjaStarter.totalSold.call()).toString()).to.be.equal(toWei('100').toString())
        expect((await ninjaStarter.busdDeposits.call(user)).toString()).to.be.equal(toWei('5').toString())
        expect((await ninjaStarter.purchases.call(user)).toString()).to.be.equal(toWei('100').toString())
    })
    it('Buy maximum offering token check max buy condition', async () => {
        await ninjaStarter.buyWithBusd(toWei('300000'), { from: user })
        expect((await ninjaStarter.totalCollectedBUSD.call()).toString()).to.be.equal(toWei('250000').toString())
        expect((await ninjaStarter.totalSold.call()).toString()).to.be.equal(toWei('5000000').toString())
        expect((await ninjaStarter.busdDeposits.call(user)).toString()).to.be.equal(toWei('250000').toString())
        expect((await ninjaStarter.purchases.call(user)).toString()).to.be.equal(toWei('5000000').toString())
    })
    it('Claim Tokens should reject', async () => {
        await expectRevert(
            ninjaStarter.initialTokenClaim({ from: user }),
            'Token Claims are not opened'
        );
    })
    it('Refund claim  should reject', async () => {
        await expectRevert(
            ninjaStarter.claimRefund({ from: user }),
            'Refund Claims are not opened'
        );
    })
    it('Claim Tokens should reject as user have not bought any token', async () => {
        await ninjaStarter.setClaimsSettings(true, true, { from: Owner })
        await expectRevert(
            ninjaStarter.initialTokenClaim({ from: tempuser }),
            'You have not bought any token'
        );
    })
    it('Refund claim should reject as user have not bought any token', async () => {
        await expectRevert(
            ninjaStarter.claimRefund({ from: tempuser }),
            'You have not bought any token or already claimed refund'
        );
    })
 

    it('Succesfully claim 20% tokens initially', async () => {
        await ninjaStarter.initialTokenClaim({ from: user })
        expect((await offeringToken.balanceOf.call(user)).toString()).to.be.equal(
            toWei('1000000').toString()
        )
    })
    it('Release tokens after  vesting time period', async () => {
        await advanceTime(2629743 * 1);
        ({ logs } = await ninjaStarter.releaseAll({ from: user }));
        expectEvent.inLogs(logs, 'TokenVestingReleased', {
            vestingId: new BN('0'),
            beneficiary: user,
            amount: new BN(toWei('4000000').toString())
        })
        expect((await offeringToken.balanceOf.call(user)).toString()).to.be.equal(
            toWei('5000000').toString()
        )
    })
    it('TX should revert Release tokens as all tokens claimed already', async () => {
        await expectRevert(
            ninjaStarter.releaseAll({ from: user }),
            'No token available to claim'
        );
    })

    it('Succesfully claim Refund', async () => {
        ({ logs } = await ninjaStarter.claimRefund({ from: user }));
        expectEvent.inLogs(logs, 'Refunded', {
            buyer: user,
            amountRefunded: new BN(toWei('250000').toString())
        })
    })
    it('TX should revert claim refund as it is already claimed', async () => {
        await expectRevert(
            ninjaStarter.claimRefund({ from: user }),
            'You have not bought any token or already claimed refund'
        );
    })

})
