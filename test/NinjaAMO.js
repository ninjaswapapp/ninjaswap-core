const BigNumber = require('bignumber.js')
const BN = require('bn.js')
const { balance, constants, ether, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const chai = require('chai')
chai.use(require('chai-as-promised'))
chai.use(require('chai-bignumber')(BigNumber))

const expect = chai.expect


const NinjaIBCO = artifacts.require("NinjaIBCO")
const BondingCurve = artifacts.require('BondingCurve')
const NinjaToken = artifacts.require('NinjaToken');


contract('NinjaIBCO', (accounts) => {
    const { toWei } = web3.utils;
    const { fromWei } = web3.utils;
    let curve;
    let ninjaToken;
    let ibco;
    const Owner = accounts[0]
    const buyerOne = accounts[1]
    const buyerTwo = accounts[2]
    const buyerThree = accounts[3]
    const wallet = accounts[4]
    const INIT_BALANCE = toWei('100000');
    before (async () => {
        curve = await BondingCurve.new({from: Owner})
        ninjaToken = await NinjaToken.new({from: Owner})
        ibco = await NinjaIBCO.new(curve.address, ninjaToken.address, wallet, {from: Owner});
        await ninjaToken.updateIBCO(ibco.address , {from :Owner});
    })

    it('NINJA IBCO Should intial correctly', async () => {
        expect(await ibco.CURVE()).to.be.equal(curve.address)
        expect(await ibco.NINJA()).to.be.equal(ninjaToken.address)
        expect(await ninjaToken.IBCO()).to.be.equal(ibco.address)
    })
    it('should only allow owner to initialize', async () => {
        await expectRevert(
          ibco.initialize(toWei('1000000'), toWei('2000000'),{from: buyerOne}),
          'Ownable: caller is not the owner'
        );
    })
    it('revert to initialize as maximum softcap 1 million ninjas', async () => {
        await expectRevert(
          ibco.initialize(toWei('2000000'), toWei('2000000'),{from: Owner}),
          'Maximum softcap 1M ninja Tokens'
        );
    })
    it('revert to initialize as maximum hardcap 2 million ninjas', async () => {
        await expectRevert(
          ibco.initialize(toWei('1000000'), toWei('3000000'),{from: Owner}),
          'Maximum hardcap 2M ninja Tokens'
        );
    })
    it('should initialize with 10k ninjas softcap and 20k hardcap', async () => {
          await ibco.initialize(toWei('10000'), toWei('20000'),{from: Owner});
          expect(toWei('10000').toString()).to.be.equal((await ibco.softcap()).toString())
          expect(toWei('20000').toString()).to.be.equal((await ibco.hardcap()).toString())
    })
    it('estimated tokens from curve should be 22079251376429050851547', async () => {
        var estimate = await ibco.getEstimatedContinuousMintReward(toWei('2'));
        expect(estimate.toString()).to.be.equal('22079251376429050851547')
    })
    it('Test buy function with 1 bnb investment', async () => {
        var estimate = await ibco.getEstimatedContinuousMintReward(toWei('1'));
        await ibco.buy(toWei('1') ,{from:buyerOne ,  value: toWei('1')});
        var balance = await ninjaToken.balanceOf.call(buyerOne);
        // Buyer balance should be same as estimate
        expect(estimate.toString()).to.be.equal(balance.toString()) 
        // Buyer deposit should be recorded correct
        expect(toWei('1').toString()).to.be.equal((await ibco.deposits.call(buyerOne)).toString())
        // IBCO smart contract should have 1 bnb
         expect(toWei('1').toString()).to.be.equal((await web3.eth.getBalance(ibco.address)).toString())
        // treasury wallet should have same minted tokens
        expect(estimate.toString()).to.be.equal( (await ninjaToken.balanceOf.call(wallet)).toString())

         // IBCO minted tokens should be recorded correctly
         expect(estimate.mul(new BN('2')).toString()).to.be.equal((await ninjaToken.IBCOMinted()).toString())
    })
    it('Test buy with referral for 1 bnb investment', async () => {
        var estimate = await ibco.getEstimatedContinuousMintReward(toWei('1'));
        await ibco.buyWithRef(buyerThree , toWei('1') ,{from:buyerTwo ,  value: toWei('1')});
        var balance = await ninjaToken.balanceOf.call(buyerTwo);
        var refShare = estimate.mul(new BN('10')).div(new BN('100'));
        var bonus = await ibco.bonus.call(buyerThree)
        // Referral earning should be 10% of estimated tokens  
        expect(refShare.toString()).to.be.equal( (await ninjaToken.balanceOf.call(buyerThree)).toString()) 
        // Buyer balance should be same as estimate
        expect(estimate.toString()).to.be.equal(balance.toString()) 
        // Buyer deposit should be recorded correct
        expect(toWei('1').toString()).to.be.equal((await ibco.deposits.call(buyerTwo)).toString())
        // Referral bonus count should be 1 
        expect('1').to.be.equal((bonus.count).toString())
        // Referral user earning should be same as calculated  
        expect(refShare.toString()).to.be.equal((bonus.amount).toString())
       
    })
    it('Buy should revert as sale reach at hardcap', async () => {
        await expectRevert(
         ibco.buy(toWei('1') ,{from:buyerOne ,  value: toWei('1')}),
          'IBCO Stopped : Sales reached at hardcap'
        );
    })
    it('should only allow owner to withdraw bnb', async () => {
      await expectRevert(
        ibco.withdrawBNB({from: buyerOne}),
        'Ownable: caller is not the owner'
      );
    })

    it('should successfully withdraw 1 bnb', async () => {
        await ibco.withdrawBNB({from: Owner});
       await expect('0').to.be.equal((await web3.eth.getBalance(ibco.address)).toString())
    })

    // it('should reject Claim Marketing funds due to not reach softcap', async () => {
    //     await expectRevert(
    //         ibco.withdrawMarketingFunds({from: Owner}),
    //         'marketing funds can be claim once reach softcap'
    //       );
    //   });
 
})
