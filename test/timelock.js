const { time } = require('@openzeppelin/test-helpers')
const ethers = require('ethers')
const XNinjaSwap = artifacts.require('XNinjaSwap')
const XNinjaMaster = artifacts.require('XNinjaMaster')
const Timelock = artifacts.require('Timelock')

const { BN } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')
const { web3 } = require('@openzeppelin/test-helpers/src/setup')

require('chai')
  .use(require('chai-bn')(BN))
  .use(require('chai-as-promised'))
  .should()

contract('Timelock', ([deployer, alice, bob, carol, governor]) => {
  beforeEach(async () => {
    const currentBlock = await web3.eth.getBlockNumber()
    const currentTime = Number(await time.latest())
    this.token = await XNinjaSwap.new()
    this.ninjaMaster = await XNinjaMaster.new(this.token.address, deployer, deployer, '30000000000000000', currentBlock)
    this.timelock = await Timelock.new(172800) // timelock with delay of 2 day
    await this.ninjaMaster.transferOwnership(this.timelock.address)
    await this.token.replaceMinter(this.timelock.address)
    this.queueParams = [
      this.ninjaMaster.address,
      0,
      'updateEmissionRate(uint256)',
      ethers.utils.defaultAbiCoder.encode(['uint256'], ['100000000']),
      currentTime + 172900
    ]
    this.queueMintParams = [
      this.token.address,
      0,
      'mint(address,uint256)',
      ethers.utils.defaultAbiCoder.encode(['address','uint256'], [alice ,'500000000000000000000']),
      currentTime + 172900
    ]
  })

  describe('queueTransaction', () => {
    it('should queue a transaction without executing it', async () => {
      const txHash = await this.timelock.queueTransaction.call(...this.queueParams)
      expect(await this.timelock.queuedTransactions(txHash)).to.be.eq(false)
      await this.timelock.queueTransaction(...this.queueParams)
      expect(await this.timelock.queuedTransactions(txHash)).to.be.eq(true)
      expect((await this.ninjaMaster.xninjaPerBlock()).toString()).to.be.eq('30000000000000000')
    })
  })
  describe('executeTransaction', () => {
    it('should allow to execute a queued transaction after the delay', async () => {
      await this.timelock.queueTransaction(...this.queueParams)
      expect((await this.ninjaMaster.xninjaPerBlock()).toString()).to.be.eq('30000000000000000')
      await time.increase(time.duration.days(3))
      await this.timelock.executeTransaction(...this.queueParams)
      expect((await this.ninjaMaster.xninjaPerBlock()).toString()).to.be.eq('100000000')
    })

    it('should not allow to execute a queued transaction before the delay', async () => {
      await this.timelock.queueTransaction(...this.queueParams)
      expect((await this.ninjaMaster.xninjaPerBlock()).toString()).to.be.eq('30000000000000000')
      await this.timelock.executeTransaction(...this.queueParams)
        .should.be.rejectedWith('Transaction hasn\'t surpassed time lock')
    })
  })

  describe('cancelTransaction', () => {
    it('should cancel a queued transaction', async () => {
      const txHash = await this.timelock.queueTransaction.call(...this.queueParams)
      await this.timelock.queueTransaction(...this.queueParams)
      expect(await this.timelock.queuedTransactions(txHash)).to.be.eq(true)
      await this.timelock.cancelTransaction(...this.queueParams)
      expect(await this.timelock.queuedTransactions(txHash)).to.be.eq(false)
    })
  })
  describe('executeMintTransaction', () => {
    it('should allow to execute a mint queued transaction after the delay', async () => {
      await this.timelock.queueTransaction(...this.queueMintParams)
      expect((await this.token.balanceOf(alice)).toString()).to.be.eq('0')
      await time.increase(time.duration.days(3))
      await this.timelock.executeTransaction(...this.queueMintParams)
      expect((await this.token.balanceOf(alice)).toString()).to.be.eq('500000000000000000000')
    })
  })
})
