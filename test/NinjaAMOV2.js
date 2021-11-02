// const BigNumber = require('bignumber.js')
const BN = require('bn.js')
const Web3 = require('web3')
const { constants, utils } = require("ethers");
const web3 = new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:7545'))
const { getGasCost } = require('./utils')

const {
  balance,
  ether,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers')

const chai = require('chai')
chai.use(require('chai-as-promised'))
// chai.use(require('chai-bignumber')(BigNumber))

const expect = chai.expect

const MockERC20 = artifacts.require('MockERC20')
const NinjaToken = artifacts.require('NinjaToken');
const NinjaAMOV2 = artifacts.require('NinjaAMOV2');
const NinjaBounty = artifacts.require('NinjaBounty');

contract('NinjaAMOV2', (accounts) => {
  const { toWei } = web3.utils
  const { fromWei } = web3.utils
  const INIT_BALANCE = toWei('80000')
  let ninjaStarter
  let ffToken
  let busd
  let ninjaToken;
  let ninjaAmov2;
  let ninjaBounty;
  const Owner = accounts[0]
  const ffOwner = accounts[1]
  const feeAddress = accounts[2]
  const user = accounts[3];
  const buyerBnBCap = accounts[4];
  const buyerBusdCap = accounts[5];
  const Treasury = accounts[6];
  before(async () => {
  
    ninjaBounty = await NinjaBounty.new({from: Owner})
    ninjaToken = await NinjaToken.new(ninjaBounty.address, {from: Owner})
    busd = await MockERC20.new('Binance USD', 'BUSD', toWei('17200000'), {
      from: user,
    })
    ninjaAmov2 = await NinjaAMOV2.new(
        ninjaToken.address,
        busd.address,
        Treasury,
        Treasury,
        feeAddress,
        { from: Owner },
      )
      await ninjaToken.updateAMO(ninjaAmov2.address , {from :Owner});
  })
  it('NINJA IBCO Should intial correctly', async () => {
    expect(await ninjaToken.AMO()).to.be.equal(ninjaAmov2.address)
})


  it('Mint 20 tokens with 50 BUSD', async () => {
    await busd.approve(ninjaAmov2.address, constants.MaxUint256, {
      from: user,
    })
    await ninjaAmov2.mintWithBUSD(toWei('50'), { from: user })
    var Minted = await ninjaAmov2.Minted.call(user)
    expect(Minted.toString()).to.be.equal(toWei('20').toString())
    expect((await ninjaToken.balanceOf.call(user)).toString()).to.be.equal(
      toWei('20').toString()
    )
  })

  it('total amo minted tokens should be 20', async () => {
    expect((await ninjaToken.AMOMinted.call()).toString()).to.be.equal(
      toWei('23').toString() // amo minted + team minted tokens
    )
    expect((await ninjaAmov2.TotalAMOV2Mints.call()).toString()).to.be.equal(
      toWei('20').toString()
    )
  })
  it('Mint 2.8 million tokens with 17100000 BUSD', async () => {
    await busd.approve(ninjaAmov2.address, constants.MaxUint256, {
      from: user,
    })
    await ninjaAmov2.mintWithBUSD(toWei('17100000'), { from: user })
    var Minted = await ninjaAmov2.Minted.call(user)
    expect(Minted.toString()).to.be.equal((await ninjaToken.balanceOf.call(user)).toString())
    expect((await ninjaAmov2.totalAMOTokens.call()).toString()).to.be.equal(
      ('2799999999999999999999999').toString()
    )
  })
  it('AMO should be pause', async () => {
    await ninjaAmov2.pause({ from: Owner });
    await ninjaAmov2.withdrawFunds({ from: Owner });
    console.log((await busd.balanceOf.call(Treasury)).toString())
    expect(await ninjaAmov2.paused.call()).to.be.equal(
     true
    )
   
  })
})
