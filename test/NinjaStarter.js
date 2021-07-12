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

const NinjaStarter = artifacts.require('NinjaStarter')
const MockERC20 = artifacts.require('MockERC20')

contract('NinjaStarter', (accounts) => {
  const { toWei } = web3.utils
  const { fromWei } = web3.utils
  const INIT_BALANCE = toWei('80000')
  let ninjaStarter
  let ffToken
  let busd
  const Owner = accounts[0]
  const ffOwner = accounts[1]
  const feeAddress = accounts[2]
  const user = accounts[3];
  const buyerBnBCap = accounts[4];
  const buyerBusdCap = accounts[5];
  before(async () => {
    ffToken = await MockERC20.new('FF Token', 'FFF', INIT_BALANCE, {
      from: ffOwner,
    })
    busd = await MockERC20.new('Binance USD', 'BUSD', toWei('30000'), {
      from: user,
    })
    ninjaStarter = await NinjaStarter.new(
      ffToken.address,
      busd.address,
      ffOwner,
      feeAddress,
      { from: Owner },
    )
  })

  it('Buy limit on each user should be zero', async () => {
    expect((await ninjaStarter.buyCap()).toString()).to.be.equal('0')
  })

  it('1 BNB investment esitmated tokens should be 71964275000000000000 (71.964275)', async () => {
    expect(
      (await ninjaStarter.getEstimatedTokensBuyWithBNB(toWei('1'))).toString(),
    ).to.be.equal('71964275000000000000')
  })

  it('should only allow owner to setOfferingAmount', async () => {
    await expectRevert(
      ninjaStarter.setOfferingAmount(toWei('4000'), { from: user }),
      'Ownable: caller is not the owner',
    )
  })

  it('Set offering token amount to 4000', async () => {
    await ninjaStarter.setOfferingAmount(toWei('4000'), { from: Owner })
    expect((await ninjaStarter.offeringAmount()).toString()).to.be.equal(
      toWei('4000').toString(),
    )
  })

  it('Buy offering tokens with 1 BNB and total Sale Participants should be 1 ', async () => {
    await ffToken.transfer(ninjaStarter.address, toWei('4000'), {
      from: ffOwner,
    })
    await ninjaStarter.buywithBNB(user, { from: user, value: toWei('1') })
    expect((await ninjaStarter.totalSaleParticipants()).toString()).to.be.equal(
      '1',
    )
  })

  it('User should have 71964275000000000000 (71.964275) offering tokens against 1 bnb', async () => {
    expect((await ffToken.balanceOf.call(user)).toString()).to.be.equal(
      '71964275000000000000',
    )
  })

  it('totalCollectedBNB should be 1 bnb', async () => {
    expect((await ninjaStarter.totalCollectedBNB()).toString()).to.be.equal(
      toWei('1').toString(),
    )
  })

  it('totalCollectedBNB should equals to ninjastarter bnb balance', async () => {
      const totalCollectedBNB = (await ninjaStarter.totalCollectedBNB()).toString() 
      const ninjaSBalance = await web3.eth.getBalance(ninjaStarter.address)
      expect(totalCollectedBNB).to.be.equal(ninjaSBalance)
  })

  it('There should be  71964275000000000000 (71.964275 ) total sold tokens', async () => {
    expect((await ninjaStarter.totalSold()).toString()).to.be.equal(
      '71964275000000000000',
    )
  })

  it('Buy 10 offering tokens with 40 BUSD', async () => {
    await busd.approve(ninjaStarter.address, constants.MaxUint256, {
      from: user,
    })
    await ninjaStarter.buyWithBusd(toWei('40'), { from: user })
    var deposit = await ninjaStarter.busdDeposits.call(user)
    expect(deposit.toString()).to.be.equal(toWei('40').toString())
  })

  it('Set Buy cap to 71964275000000000000 tokens (71.964275)', async () => {
    const limit = '71964275000000000000';
    await ninjaStarter.setBuyCap(limit, { from: Owner })
    expect((await ninjaStarter.buyCap()).toString()).to.be.equal(
        limit.toString(),
    )
  })

  it('Buy with 2 BNB due to limit 1 bnb should be return and bought tokens only 71964275000000000000 (71.964275)', async () => {
    const balanceBefore = new BN(await web3.eth.getBalance(buyerBnBCap))
    const txInfo =  await ninjaStarter.buywithBNB(user, { from: buyerBnBCap, value: toWei('2') })
    const gasCost = await getGasCost(txInfo)
    const balanceAfter = new BN(await web3.eth.getBalance(buyerBnBCap))
    let oneBnb = new BN(toWei('1'));
    const bdiff = balanceBefore.sub(gasCost).sub(balanceAfter); 
    expect(bdiff.toString()).to.be.equal(
        oneBnb.toString(),
    )
      // 1 bnb and 71964275000000000000 tokens solds 
  })
  it('should revert buy due to buy limit reach', async () => {
    await expectRevert(
     ninjaStarter.buywithBNB(user, { from: buyerBnBCap, value: toWei('2') }),
      "You've reached your limit of purchases",
    )
  })
  it('set limit to 10 tokens and try to buy 20 tokens should return 40 busd', async () => {
    await ninjaStarter.setBuyCap(toWei('10'), { from: Owner })
    await busd.transfer(buyerBusdCap, toWei('80'), {
      from: user,
    })
    await busd.approve(ninjaStarter.address, constants.MaxUint256, {
      from: buyerBusdCap,
    })
    await ninjaStarter.buyWithBusd(toWei('80'), { from: buyerBusdCap })
    var deposit = await ninjaStarter.busdDeposits.call(buyerBusdCap)
    expect(deposit.toString()).to.be.equal(toWei('40').toString())
  })
  it('Do End Offering and should burn all remaining Tokens', async () => {
    await ninjaStarter.endOffering( { from: Owner })
    let afterBurnB = await ffToken.balanceOf.call(ninjaStarter.address); 
    expect('0').to.be.equal(afterBurnB.toString())
  })

  it('Do Final Withdraw balance should be receive correctly', async () => {
    const BusdBalance = new BN(await busd.balanceOf.call(ninjaStarter.address));
    const bnbBalance = new BN(await web3.eth.getBalance(ninjaStarter.address));
    const busdFee = BusdBalance.mul(new BN('150')).div(new BN('10000'));
    const bnbFee = bnbBalance.mul(new BN('150')).div(new BN('10000'));
    const feeAddressBBBalance = new BN(await web3.eth.getBalance(feeAddress));
    const ffownerBBBalance =  new BN(await web3.eth.getBalance(ffOwner));
    await ninjaStarter.finalWithdraw( { from: Owner })
    const ownerBusdB = new BN(await busd.balanceOf.call(ffOwner))
    const feeAddbusdB =  new BN(await busd.balanceOf.call(feeAddress))
    const ffownerBABalance =  new BN(await web3.eth.getBalance(ffOwner));
    const feeAddressBABalance = new BN(await web3.eth.getBalance(feeAddress)); 
    expect((BusdBalance.sub(busdFee)).toString()).to.be.equal(ownerBusdB.toString())
  })
})
