// const BigNumber = require('bignumber.js')
const { time } = require('@openzeppelin/test-helpers')
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
const XNinjaSwap = artifacts.require('XNinjaSwap');
const XNinjaMaster= artifacts.require('XNinjaMaster');
 const advanceBlock = () => {
  return new Promise((resolve, reject) => {
      (web3.currentProvider.send)({
          jsonrpc: '2.0',
          method: 'evm_mine',
          id: new Date().getTime(),
      }, ((err, result) => {
          if (err) { return reject(err); }
          return resolve()
      }))
  })
}
 const advanceBlocks = async (blocks) => {
  for (let i = 0; i < blocks; i++) {
      await advanceBlock();
  }
}
contract('NinjaStarter', (accounts) => {
    const { toWei } = web3.utils
    const { fromWei } = web3.utils
    const INIT_BALANCE = toWei('80000')
    let ninjaStarter
    let xninjaSwap
    let xninjaMaster;
    let ffToken
    let busd
    const Owner = accounts[0]
    const xninjaOwner = accounts[1]
    const feeAddress = accounts[2]
    const user = accounts[3];
    const buyerBnBCap = accounts[4];
    const buyerBusdCap = accounts[5];
    const ffOwner = accounts[6]
    before(async () => {
      ffToken = await MockERC20.new('FF Token', 'FFF', INIT_BALANCE, {
        from: ffOwner,
      })
      busd = await MockERC20.new('Binance USD', 'BUSD', toWei('30000'), {
        from: ffOwner,
      })
      ninjaStarter = await NinjaStarter.new(
        ffToken.address,
        ffOwner,
        { from: Owner },
      )
      xninjaSwap =  await XNinjaSwap.new({from: xninjaOwner})
      xninjaMaster = await XNinjaMaster.new(xninjaSwap.address , { from: Owner });
      await ninjaStarter.setIDoAddresses(feeAddress,busd.address ,xninjaMaster.address , feeAddress ,{ from: Owner })
      await xninjaSwap.replaceMasterChef(xninjaMaster.address , {from : xninjaOwner});
      await xninjaMaster.add('1500' , ffToken.address , '604800',true , {from : Owner});
      await ffToken.transfer(ninjaStarter.address,  toWei('70000'), {
        from: ffOwner,
      })
      // deposit fftokens to masterChef
      await ffToken.approve(xninjaMaster.address, constants.MaxUint256, {
        from: ffOwner,
      })
      await xninjaMaster.deposit('0' , toWei('200'),{from : ffOwner});
    })
  
    
    it('ninjaStarter should intial correctly', async () => {
      expect((await ninjaStarter.offeringToken()).toString()).to.be.equal(ffToken.address.toString())
      expect((await ninjaStarter.BUSD()).toString()).to.be.equal(
        busd.address.toString()
      
        )
    })
    it('Buy 10 offering tokens with 40 BUSD', async () => {
      await busd.approve(ninjaStarter.address, constants.MaxUint256, {
        from: ffOwner,
      })
      await ninjaStarter.buyWithBusd(toWei('160'), { from: ffOwner })
      var deposit = await ninjaStarter.busdDeposits.call(ffOwner)
      expect(deposit.toString()).to.be.equal(toWei('160').toString())
      expect((await ninjaStarter.totalSaleParticipants()).toString()).to.be.equal(
        '1',
      )
    })
    it('withdraw from xmasterchef should be reject', async () => {
      var vestings = await  ninjaStarter.myVestings.call(ffOwner);
      console.log("vestings : " + JSON.stringify(vestings));
      console.log("whitelisted : " + (await  ninjaStarter.isWhitelisted.call(ffOwner)));
      await expectRevert(
        xninjaMaster.withdraw('0',toWei('100'), { from: ffOwner }),
        'withdraw: lock time not reach',
      )
    })

    // it('withdraw all vestings afer 4 months', async () => {
    //   // await time.increase(time.duration.weeks(20))
    //   await  ninjaStarter.WithdrawFunds({from : Owner});
    //   var withdraw = await  ninjaStarter.releaseAll({from : ffOwner});
    //   console.log("vestings : " + JSON.stringify(withdraw));
    //   await expectRevert(
    //     xninjaMaster.withdraw('0',toWei('100'), { from: ffOwner }),
    //     'withdraw: lock time not reach',
    //   )
    // })
  })