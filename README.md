# LRT-rsETH

Kelp DAO (https://www.kelpdao.xyz/restake/) is liquid restaking protocol currently building on top of EigenLayer.
It gives users access to multiple benefits like restaking rewards, staking rewards, DeFi and liquidity.

## Table of Content

- [Build - Deploy - Verify - Test](#getting-started)
  - [Setup](#setup)
  - [Build](#develop)
  - [Deploy](#deploy)
  - [Verify](#verify-contracts)
  - [Test](#test)
- [Deployed Contracts](#deployed-contracts)
  - [Goerli Testnet](#goerli-testnet)
  - [Ethereum](#eth-mainnet)
  - [Arbitrum](#arbitrum)
  - [Manta](#manta)
  - [Mode](#mode)
  - [Blast](#blast)
  - [Base](#base)
  - [Optimism](#optimism)
  - [Scroll](#scroll)
  - [Linea](#linea)
  - [XLayer](#xlayer)
  - [ZKSync](#zksync)
- [Safe Multisigs](#safe-multisigs)
- [Bridged RSETH](#bridged-rseth)
  - [CCIP (Chainlink)](#ccip-chainlink-rseth)
  - [LayerZero OFT](#layerzero-oft-rseth)
- [RSETH Rate Providers](#rseth-pricerate-providers)

.
.

# Getting Started

## Setup

Install dependencies

```bash
npm install

forge install
```

copy .env.example to .env and fill in the values

```bash
cp .env.example .env
```

## Develop

This is a list of the most frequently needed commands.

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ npm run lint
```

## Deploy

Check `Makefile` to see a list of deploy commands for different use-cases.
Below are few sample deploy commands.

### Deploy to testnet

```bash
make deploy-lrt-testnet
```

### Deploy to Anvil:

```bash
make deploy-lrt-local-test
```

### General Deploy Script Instructions

Create a Deploy script in `script/Deploy.s.sol`:

and run the script:

```sh
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

## Verify Contracts

Follow this pattern
`contractAddress=<contractAddress> contractPath=<contract-path> make verify-lrt-proxy-testnet`

Example:

```bash
contractAddress=0xE7b647ab9e0F49093926f06E457fa65d56cb456e contractPath=contracts/LRTConfig.sol:LRTConfig  make verify-lrt-proxy-testnet
```

Verify contracts on Blockscout

1. Flatten contract and copy to clipboard

```bash
    forge flatten contracts/LRTConfig.sol:LRTConfig | pbcopy
```

2. Go to Blockscout and click on the contract address
3. Click on the `Contract` tab
4. Click on `Verify and Publish` button
5. Paste the flattened contract in the `Contract Code` field
6. Click on `Verify and Publish` button

Note: you may need to find the exact EVM compiler for the contract, e.g. Paris, Shaghai, etc

## Test

Run the tests:

```sh
$ forge test
```

Generate test coverage and output result to the terminal:

```sh
$ npm test:coverage
```

Generate test coverage with lcov report (you'll have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

```sh
$ npm test:coverage:report
```

## Using Static Analyzer for the contracts

Lib used [Aderyn](https://docs.cyfrin.io/)

- Installation

```bash
cargo install aderyn
```

- Run the static analysis

```bash
aderyn [Option] [Path]
```

Example:

```bash
aderyn -s contracts/FeeReceiver.sol
```

See List of options [here](https://docs.cyfrin.io/aderyn-static-analyzer/cli-options)
or run `aderyn --help`

.
.

# Deployed Contracts

## Goerli testnet

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x4ae77FdfB3BBBe99598CAfaE4c369b604b6d9e02 |
| ProxyAdmin       | 0xa6A6b35d84B20077c6f3d30b86547fF837260407 |
| ProxyAdmin Owner | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47 |

| Contract Name        | Proxy Address                              |
| -------------------- | ------------------------------------------ |
| LRTConfig            | 0x6d7888Bc794C1104C64c28F4e849B7AE68231b6d |
| RSETH                | 0xb4EA9175e99232560ac5dC2Bcbe4d7C833a15D56 |
| LRTDepositPool       | 0xd51d846ba5032b9284b12850373ae2f053f977b3 |
| LRTOracle            | 0xE92Ca437CA55AAbED0CBFFe398e384B997D4CCe9 |
| ChainlinkPriceOracle | 0x750604fAbF4828d1CaA19022238bc8C0DD6C50D5 |
| EthXPriceOracle      | 0x6DA0235202D9443674abe6d0355AdD147B6396A2 |

### NodeDelegator Proxy Addresses

- NodeDelegator proxy 1: 0x560B95A0Ba942A7E15645F655731244680fA030B
- NodeDelegator proxy 2: 0x32c1329fE006CDE9dac246293135E98e0070Afa0
- NodeDelegator proxy 3: 0x5520e0ECE7a82a72325417732131dbeCe0b5F0Fb
- NodeDelegator proxy 4: 0x385C2636bAe9145eb9A52a05A58f181440c2fcE3
- NodeDelegator proxy 5: 0x8C58090994913Cb3cb017F544156d76F6c42F37c

## ETH Mainnet

| Contract Name     | Address                                    |
| ----------------- | ------------------------------------------ |
| ProxyFactory      | 0x673a669425457bCabeb247f56552A0Fd8141cee2 |
| ProxyAdmin        | 0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78 |
| ProxyAdmin Owner  | 0x49bD9989E31aD35B0A62c20BE86335196A3135B1 |
| TimeLock          | 0x49bD9989E31aD35B0A62c20BE86335196A3135B1 |
| Timelock Proposer | 0xb3696a817D01C8623E66D156B6798291fa10a46d |

| Contract Name        | Proxy Address                              |
| -------------------- | ------------------------------------------ |
| LRTConfig            | 0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7 |
| RSETH                | 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7 |
| LRTDepositPool       | 0x036676389e48133B63a802f8635AD39E752D375D |
| LRTOracle            | 0x349A73444b1a310BAe67ef67973022020d70020d |
| ChainlinkPriceOracle | 0x78C12ccE8346B936117655Dd3D70a2501Fd3d6e6 |
| SfrxETHPriceOracle   | 0x8546A7C8C3C537914C3De24811070334568eF427 |
| EthXPriceOracle      | 0x3D08ccb47ccCde84755924ED6B0642F9aB30dFd2 |
| SwETHPriceOracle     | 0xCB8f20a144bFA15066148A1F29F1091d15B25f93 |
| RETHPriceOracle      | 0x585839c360872731Fc271183b9F703654ce08275 |
| FeeReceiver          | 0xdbC3363De051550D122D9C623CBaff441AFb477C |
| KelpEarnedPoint      | 0x8E3A59427B1D87Db234Dd4ff63B25E4BF94672f4 |
| MerkleDistributor    | 0x2DDB11443bD9Ceb92d4951A05f55eb7096EB53d3 |
| LRTConverter         | 0x598dbcb99711E5577fF76ef4577417197B939Dfa |
| LRTWithdrawalManager | 0x62De59c08eB5dAE4b7E6F7a8cAd3006d6965ec16 |
| LRTUnstakingVault    | 0xc66830E2667bc740c0BED9A71F18B14B8c8184bA |

### NodeDelegator Proxy Addresses

- NodeDelegator proxy index 0: 0x07b96Cf1183C9BFf2E43Acf0E547a8c4E4429473
- NodeDelegator proxy index 1: 0x429554411C8f0ACEEC899100D3aacCF2707748b3
- NodeDelegator proxy index 2: 0x92B4f5b9ffa1b5DB3b976E89A75E87B332E6e388
- NodeDelegator proxy index 3: 0x9d2Fc9287e1c3A1A814382B40AAB13873031C4ad
- NodeDelegator proxy index 4: 0xe8038228ff1aEfD007D7A22C9f08DDaadF8374E4
- NodeDelegator proxy index 5: 0x049EA11D337f185b1Aa910d98e8Fbd991f0FBA7B
- NodeDelegator proxy index 6: 0x545D69B99759E7b670Df243b882700121d6d3AB9
- NodeDelegator proxy index 7: 0xee5470E1519972C3eA95249d60EBD064af2D53D3
- NodeDelegator proxy index 8: 0x4C798C4653b1257D5149910523D7a6eeD5712F83
- NodeDelegator proxy index 9: 0x79f17234746344E0365D40be50d8d43DB9082c32
- NodeDelegator proxy index 10: 0x395884D1974a839702bcFCBa176AC7871c788946
- NodeDelegator proxy index 11: 0xFc561966ceaAa09f4d6CBa4AdD54778c2bF1cB85

## Arbitrum

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x81E5c1483c6869e95A4f5B00B41181561278179F |
| ProxyAdmin       | 0x4938c803EBe999FB0A5527310662624f2E7A38C1 |
| ProxyAdmin Owner | 0x96D97D66d4290C9182A09470a5775FF90DAf922c |

| Contract Name | Proxy Address                              |
| ------------- | ------------------------------------------ |
| RSETHPool     | 0x376A7564AF88242D6B8598A5cfdD2E9759711B61 |

## Manta

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72 |
| ProxyAdmin       | 0x2B1CbD412565c0a2D32E62Ab7304bb464C644cc1 |
| ProxyAdmin Owner | 0x84efef1439f1b6f264866f65062ba49df764be08 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0x9dd4f9EeE9B05D1ebec1d4aAE7Ae9F5d8D235CD4 |

## Mode

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x30c2B5f5c74B855d99792E485bDBcE1dD2f2e1A9 |
| ProxyAdmin       | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72 |
| ProxyAdmin Owner | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd |
| RSETHPoolV2       | 0xbDf612E616432AA8e8D7d8cC1A9c934025371c5C |

## Blast

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x30c2B5f5c74B855d99792E485bDBcE1dD2f2e1A9 |
| ProxyAdmin       | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72 |
| ProxyAdmin Owner | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd |
| RSETHPoolV2       | 0x1558959f1a032F83f24A14Ff539944A926C51bdf |

## Base

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0xAd6626758Bd6d2e6f68Da203087248f59ca4fB97 |
| ProxyAdmin       | 0xDf3f5926Fd14Ed048B04941189da54BdEDD478d0 |
| ProxyAdmin Owner | 0x7Da95539762Dd11005889F6B72a6674A4888B56d |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0xEDfa23602D0EC14714057867A78d01e94176BEA0 |
| RSETHPoolV2       | 0x291088312150482826b3A37d5A69a4c54DAa9118 |

## Optimism

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x5c6AB8B02b29cd205580C02681d27Cb6246eEFbc |
| ProxyAdmin       | 0xa465eAfAfEE5629eE92832e14C37df4723816d58 |
| ProxyAdmin Owner | 0x0d30A563e38Fe2926b37783A046004A7869adE6C |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0x87eEE96D50Fb761AD85B1c982d28A042169d61b1 |
| RSETHPoolV2       | 0xaAA687e218F9B53183A6AA9639FBD9D6e69EcB73 |

## Scroll

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x1373A61449C26CC3F48C1B4c547322eDAa36eB12 |
| ProxyAdmin       | 0xAD3B3ECd2130AaaB5f1fd9aEC82879Bd8D56742D |
| ProxyAdmin Owner | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0xa25b25548B4C98B0c7d3d27dcA5D5ca743d68b7F |
| RSETHPoolV2       | 0xb80deaecd7F4Bca934DE201B11a8711644156a0a |

## Linea

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x4938c803EBe999FB0A5527310662624f2E7A38C1 |
| ProxyAdmin       | 0x352E20158C9916579b337d1332F462B26A8A699c |
| ProxyAdmin Owner | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0xD2671165570f41BBB3B0097893300b6EB6101E6C |
| RSETHPoolV2       | 0x057297e44A3364139EDCF3e1594d6917eD7688c2 |

## XLayer

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0xe119D214a6efa7d3cF60e6E59481EDe1B0064A6B |
| ProxyAdmin       | 0x3222d3De5A9a3aB884751828903044CC4ADC627e |
| ProxyAdmin Owner | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0x5A71f5888EE05B36Ded9149e6D32eE93812EE5e9 |
| RSETHPoolV3       | 0x4Ef626efE4a3A279a9DC7e7a91C1c9CaaAE8e159 |

| Contract Name | Address                                    |
| ------------- | ------------------------------------------ |
| WETHOracle    | 0x6F27976308001119a8e89cB447333DaaA3043CE7 |

## ZKSync

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyAdmin       | 0xd836801C07e9b471Fa3c525bc13bC4333c51F25F |
| ProxyAdmin Owner | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0xd4169E045bcF9a86cC00101225d9ED61D2F51af2 |
| RSETHPoolV2       | 0x41b300f5A619973b20931f0944C85DB229d5E27f |

.
.

## Safe Multisigs

| Name                       | Safe Address                                |
| -------------------------- | ------------------------------------------- |
| ETH Mainnet Manager        | 0xCbcdd778AA25476F203814214dD3E9b9c46829A1  |
| ETH Mainnet Admin          | 0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2  |
| ETH Mainnet External Admin | 0xb3696a817D01C8623E66D156B6798291fa10a46d  |
| BSC                        | 0xb4222155CDB309Ecee1bA64d56c8bAb0475a95b0  |
| Optimism                   | 0x0d30A563e38Fe2926b37783A046004A7869adE6C  |
| Arbitrum                   | 0x96D97D66d4290C9182A09470a5775FF90DAf922c  |
| Polygon ZKEVM              | 0x424Fc153C4005F8D5f23E08d94F5203D99E9B160  |
| Manta                      | 0x84eFeF1439F1b6F264866F65062Ba49Df764bE08  |
| ZkSync                     | 0xeD38DA849b20Fa27B07D073053C5F5aAe6A2dB6b  |
| Base                       | 0x7Da95539762Dd11005889F6B72a6674A4888B56d  |

.
.

## Bridged RSETH

### CCIP (Chainlink) RSETH

| Network  | Address                                    |
| -------- | ------------------------------------------ |
| Arbitrum | 0xe119D214a6efa7d3cF60e6E59481EDe1B0064A6B |
| Optimism | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72 |
| BSC      | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |

### LayerZero OFT RSETH

| Network  | Address                                    |
| -------- | ------------------------------------------ |
| Arbitrum | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Optimism | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Manta    | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Mode     | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Blast    | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Scroll   | 0x65421ba909200b81640d98B979d07487C9781B66 |
| Base     | 0x1Bc71130A0e39942a7658878169764Bbd8A45993 |

.
.

## RSETH Price/Rate Providers

### ETH Mainnet

| Contract Name               | Proxy Address                              |
| --------------------------- | ------------------------------------------ |
| RSETHMultiChainRateProvider | 0x0788906B19bA8f8d0e8a7015f0714DF3179D9aB6 |
| RSETHRateProvider           | 0xF1cccBa5558D31628216489A1435e068b1fd2C8A |
| OneETHPriceOracle           | 0x4cB8d6DCd56d6b371210E70837753F2a835160c4 |
| RSETHPriceFeed (Morph)      | 0x4B9C66c2C0d3706AabC6d00D2a6ffD2B68A4E383 |

### Arbitrum

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x3222d3De5A9a3aB884751828903044CC4ADC627e |

### Optimism

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x1373A61449C26CC3F48C1B4c547322eDAa36eB12 |

### Polygon ZKEVM

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHRateProvider on ETH mainnet as provider)           | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x30CE1444834dbd91e23317179A39d875B16F0DCd |

### Blast

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x38dd27B51E2E6868D99B615097c03A3DE7fa7AA8 |

### Mode

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x38dd27B51E2E6868D99B615097c03A3DE7fa7AA8 |

### Scroll

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0xc9BcFbB1Bf6dd20Ba365797c1Ac5d39FdBf095Da |

### Base

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x7781ae9B47FeCaCEAeCc4FcA8d0b6187E3eF9ba7 |

### Linea

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x81E5c1483c6869e95A4f5B00B41181561278179F |

### XLayer

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x30CE1444834dbd91e23317179A39d875B16F0DCd |

### ZKSync

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x6C2e862E7d03e1C9dDa1b30De69b201c7c52e3dB |
