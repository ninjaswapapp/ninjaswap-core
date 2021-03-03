const BN = require('bn.js')
const createCsvWriter = require('csv-writer').createObjectCsvWriter
const csvWriter = createCsvWriter({
  path: 'NinjaPriceGrowth_5BNB.csv',
  header: [
    { id: 'ninja', title: 'Received Ninja Tokens' },
    { id: 'price', title: 'Price in BNB' },
    { id: 'totalbnb', title: 'Total BNB' },
    { id: 'totalsupply', title: 'Total Ninja Sold' },
  ],
})
const BondingCurve = artifacts.require('BondingCurve')
const data = []
const RESERVE_RATIO_10 = 100000
const RESERVE_RATIO_33 = 300000
const ONE_TOKEN = new BN(web3.utils.toWei('1'))

function toDecimalString(bn) {
  return web3.utils.fromWei(bn).toString()
}

function effectivePrice(reserveTokenAmount, continuousTokenAmount) {
  return toDecimalString(
    reserveTokenAmount.mul(ONE_TOKEN).div(continuousTokenAmount),
  )
}

async function simulatePriceGrowth(
  contract,
  reserveRatio,
  continuousSupply,
  reserveBalance,
  purchaseIncrement,
) {
  let continuousTokenSupply = continuousSupply
  let reserveTokenBalance = reserveBalance
  let newSupply = new BN(web3.utils.toWei('0'))
  let newTotalBNB = new BN(web3.utils.toWei('0'))
  for (let i = 0; i < 200000000000; i += 1) {
    if(parseFloat(toDecimalString(newSupply)) > 1000000){
      break
    }
    const continuousTokenAmount = await contract.calculatePurchaseReturn(
      continuousTokenSupply,
      reserveTokenBalance,
      reserveRatio,
      purchaseIncrement,
    )
    newSupply = newSupply.add(continuousTokenAmount)
    newTotalBNB = newTotalBNB.add(purchaseIncrement)
    console.info(
      `${toDecimalString(purchaseIncrement)} BNB gives you ${toDecimalString(
        continuousTokenAmount,
      )} NINJA @ ${effectivePrice(
        purchaseIncrement,
        continuousTokenAmount,
      )} BNB each | total ${toDecimalString(reserveTokenBalance)}`,
    )
    var insert = {
      ninja: toDecimalString(continuousTokenAmount),
      price: effectivePrice(purchaseIncrement, continuousTokenAmount),
      totalbnb: toDecimalString(newTotalBNB),
      totalsupply: toDecimalString(newSupply),
    }
    data.push(insert)
    continuousTokenSupply = continuousTokenSupply.add(
      new BN(continuousTokenAmount),
    )
    reserveTokenBalance = reserveTokenBalance.add(purchaseIncrement)
  }
}

contract('BondingCurve', () => {
  before(async () => {
    this.formula = await BondingCurve.new()
  })

  it('calculates ninja price growth', async () => {
    const RESERVE_RATIO = RESERVE_RATIO_10
    const BUY_INCREMENT = new BN(web3.utils.toWei('5'))
    const CT_SUPPLY = new BN(web3.utils.toWei('1200000'))
    const RT_BALANCE = new BN(web3.utils.toWei('36'))

    await simulatePriceGrowth(
      this.formula,
      RESERVE_RATIO,
      CT_SUPPLY,
      RT_BALANCE,
      BUY_INCREMENT,
    )

    await csvWriter
      .writeRecords(data)
      .then(() => console.log('The CSV file was written successfully'))
    assert.equal(true, true)
  })
})
