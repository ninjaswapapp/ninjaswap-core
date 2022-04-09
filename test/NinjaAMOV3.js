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
const NinjaToken = artifacts.require('NinjaToken');
const NinjaAMOV3 = artifacts.require('NinjaAMOV3');
const NinjaBounty = artifacts.require('NinjaBountyAirdropBank');

contract('NinjaAMOV3', (accounts) => {
  const { toWei } = web3.utils
  const { fromWei } = web3.utils
  const INIT_BALANCE = toWei('17200000')
  let busd
  let ninjaToken;
  let ninjaAmov3;
  const Owner = accounts[0]
  const Treasury1 = accounts[1]
  const Treasury2 = accounts[2]
  const teamTokens = accounts[3]
  const user = accounts[4];
  const bountyAddress = accounts[5];
  const NinjaBountyAirdropBank= accounts[6];
  before(async () => {
    ninjaToken = await NinjaToken.new(bountyAddress, {from: Owner})
    busd = await MockERC20.new('Binance USD', 'BUSD', INIT_BALANCE, {
      from: user,
    })
    ninjaAmov3 = await NinjaAMOV3.new(
        ninjaToken.address,
        busd.address,
        Treasury1,
        Treasury2,
        NinjaBountyAirdropBank,
        { from: Owner },
      )
      await ninjaToken.updateAMO(ninjaAmov3.address , {from :Owner});
  })
  it('NINJA IBCO Should intial correctly', async () => {
    expect(await ninjaToken.AMO()).to.be.equal(ninjaAmov3.address)
})


  it('Mint 20 tokens with 50 BUSD', async () => {
    await busd.approve(ninjaAmov3.address, constants.MaxUint256, {from: user})
    await ninjaAmov3.mintWithBUSD(toWei('50'), { from: user })
    var busdDeposits = await ninjaAmov3.busdDeposits.call(user)
    expect((await ninjaAmov3.TotalAMOV3Mints.call()).toString()).to.be.equal(toWei('20').toString())
    expect((await ninjaAmov3.Minted.call(user)).toString()).to.be.equal(toWei('20').toString())
    expect(busdDeposits.toString()).to.be.equal(toWei('50').toString())
    expect((await ninjaAmov3.totalParticipants.call()).toString()).to.be.equal('1')
    expect((await ninjaToken.balanceOf.call(user)).toString()).to.be.equal(
      toWei('10').toString()
    )
  })
  it('TX should revert Release tokens before 1 week of vesting time period', async () => {
    await expectRevert(
      ninjaAmov3.releaseAll({from: user }),
      'No token available to claim'
    );
  })
  it('Release tokens after 1 week of vesting time period', async () => {
    await advanceTime(WeekToSeconds * 1);
    ({ logs } = await ninjaAmov3.releaseAll({from: user }));
    expectEvent.inLogs(logs, 'TokenVestingReleased', {
      vestingId: new BN('0') ,
      beneficiary: user,
      amount : new BN(toWei('10').toString())
    })
    expect((await ninjaToken.balanceOf.call(user)).toString()).to.be.equal(
      toWei('20').toString()
    )
  })
  it('TX should revert Release tokens as all tokens claimed already', async () => {
    await expectRevert(
      ninjaAmov3.releaseAll({from: user }),
      'No token available to claim'
    );
  })

  it('withdraw funds and should receive 50 busd total in Treasury1 and Treasury2', async () => {
    await  ninjaAmov3.withdrawFunds({from: Owner });
    expect((await busd.balanceOf.call(Treasury1)).toString()).to.be.equal(toWei('25').toString())
    expect((await busd.balanceOf.call(Treasury2)).toString()).to.be.equal(toWei('25').toString())
  })
  it('withdraw team locked tokens', async () => {
    // 20 minted so 0.15x means 20x15x100 = 3;
    await  ninjaAmov3.withdrawTeamTokens(teamTokens , toWei('3') , {from: Owner });
    expect((await ninjaToken.balanceOf.call(teamTokens)).toString()).to.be.equal(toWei('3').toString())
  })
  it('mint 30k ninja tokens for bounty', async () => {
    await  ninjaAmov3.mintBountyTokens({from: Owner });
    expect((await ninjaToken.balanceOf.call(NinjaBountyAirdropBank)).toString()).to.be.equal(toWei('30000').toString())
  })
  it('revert mint 30k ninja tokens for bounty as already minted', async () => {
    await expectRevert(
      ninjaAmov3.mintBountyTokens({from: Owner }),
      'Tokens already minted'
    );
  })
})
