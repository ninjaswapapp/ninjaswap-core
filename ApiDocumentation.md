# CheeSwap REST API documentation

## get all tickers

[https://api.ninjaswap.app/tickers](https://api.ninjaswap.app/tickers)

example

```text
curl --request GET
   --url https://api.ninjaswap.app/tickers
```

## get Total Liquidity in USD (TVL)

[https://api.ninjaswap.app/tickers](https://api.ninjaswap.app/totalliquidity)

example

```text
curl --request GET
   --url https://api.ninjaswap.app/totalliquidity
```
## get Total Liquidity in USD (TVL)

[https://api.ninjaswap.app/tickers](https://api.ninjaswap.app/totalliquidity)

example

```text
curl --request GET
   --url https://api.ninjaswap.app/totalliquidity
```

## get summary of all pairs

[https://api.ninjaswap.app/tickers](https://api.ninjaswap.app/summary)

example

```text
curl --request GET
   --url https://api.ninjaswap.app/summary
```

## get all listed assets

[https://api.ninjaswap.app/assets](https://api.ninjaswap.app/assets)

example

```text
curl --request GET
   --url https://api.ninjaswap.app/assets
```

##  get order of a pair

[https://api.ninjaswap.app/orderbook/{pair}](https://api.ninjaswap.app/orderbook/{pair})

### Pair name should be: tone0Address\_token1Address format

example: [https://api.ninjaswap.app/orderbook/0x93e7567f277F353d241973d6f85b5feA1dD84C10\_0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c](https://api.ninjaswap.app/orderbook/0x93e7567f277F353d241973d6f85b5feA1dD84C10_0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)

example

```text
curl --request GET
   --url https://api.ninjaswap.app/orderbook/{pair}
```

## get all trades of a pair

[https://api.ninjaswap.app/trades/{pair}](https://api.ninjaswap.app/trades/{pair})

### Pair name should be: tone0Address\_token1Address format

example: [https://api.ninjaswap.app/trades/0x93e7567f277F353d241973d6f85b5feA1dD84C10\_0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c](https://api.ninjaswap.app/trades/0x93e7567f277F353d241973d6f85b5feA1dD84C10_0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)

example

```text
curl --request GET
   --url https://api.ninjaswap.app/trades/{pair}
```

