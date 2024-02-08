# LRT-rsETH

## Setup

1. Install dependencies

```bash
npm install

forge install
```

2. copy .env.example to .env and fill in the values

```bash
cp .env.example .env
```

## Usage

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

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Deploy

## Deploy to testnet

```bash
make deploy-lrt-testnet
```

## Deploy to Anvil:

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
$ npm lint
```

### Test

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

## Deployed Contracts

### Goerli testnet

| Contract Name           | Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x4ae77FdfB3BBBe99598CAfaE4c369b604b6d9e02     |
| ProxyAdmin              | 0xa6A6b35d84B20077c6f3d30b86547fF837260407     |
| ProxyAdmin Owner        | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47     |

### Contract Implementations
| Contract Name           | Implementation Address                         |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x673a669425457bCabeb247f56552A0Fd8141cee2     |
| RSETH                   | 0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78     |
| LRTDepositPool          | 0x8D9CD771c51b7F6217E0000c1C735F05aDbE6594     |
| LRTOracle               | 0x8E2fe2f55f295F3f141213789796fa79E709eF23     |
| ChainlinkPriceOracle    | 0x2Ad42D71f65F76860FCE2C39032dEf101422b3f7     |
| EthXPriceOracle         | 0xf1BED40dbeE8FC0F324FA06322f2Bbd62d11c97d     |
| NodeDelegator           | 0xD73Cd1aaE045653474B873f3275BA2BE2744c8B4     |

### Proxy Addresses
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x6d7888Bc794C1104C64c28F4e849B7AE68231b6d     |
| RSETH                   | 0xb4EA9175e99232560ac5dC2Bcbe4d7C833a15D56     |
| LRTDepositPool          | 0xd51d846ba5032b9284b12850373ae2f053f977b3     |
| LRTOracle               | 0xE92Ca437CA55AAbED0CBFFe398e384B997D4CCe9     |
| ChainlinkPriceOracle    | 0x750604fAbF4828d1CaA19022238bc8C0DD6C50D5     |
| EthXPriceOracle         | 0x6DA0235202D9443674abe6d0355AdD147B6396A2     |

### NodeDelegator Proxy Addresses
- NodeDelegator proxy 1: 0x560B95A0Ba942A7E15645F655731244680fA030B
- NodeDelegator proxy 2: 0x32c1329fE006CDE9dac246293135E98e0070Afa0
- NodeDelegator proxy 3: 0x5520e0ECE7a82a72325417732131dbeCe0b5F0Fb
- NodeDelegator proxy 4: 0x385C2636bAe9145eb9A52a05A58f181440c2fcE3
- NodeDelegator proxy 5: 0x8C58090994913Cb3cb017F544156d76F6c42F37c


### ETH Mainnet

| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x673a669425457bCabeb247f56552A0Fd8141cee2     |
| ProxyAdmin              | 0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78     |
| ProxyAdmin Owner        | 0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2     |

### Contract Implementations
| Contract Name           | Implementation Address                         |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x8D9CD771c51b7F6217E0000c1C735F05aDbE6594     |
| RSETH                   | 0x8E2fe2f55f295F3f141213789796fa79E709eF23     |
| LRTDepositPool          | 0x2Ad42D71f65F76860FCE2C39032dEf101422b3f7     |
| LRTOracle               | 0xf1BED40dbeE8FC0F324FA06322f2Bbd62d11c97d     |
| ChainlinkPriceOracle    | 0xD73Cd1aaE045653474B873f3275BA2BE2744c8B4     |
| EthXPriceOracle         | 0x0379E85188BC416A1D43Ab04b28F38B5c63F129E     |
| SfrxETHPriceOracle      | 0xD7DB9604EF925aF96CDa6B45026Be64C691C7704     |
| NodeDelegator           | 0xeD510dea149D14c1EB5f973004E0111afdb3B179     |

### Proxy Addresses
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7     |
| RSETH                   | 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7     |
| LRTDepositPool          | 0x036676389e48133B63a802f8635AD39E752D375D     |
| LRTOracle               | 0x349A73444b1a310BAe67ef67973022020d70020d     |
| ChainlinkPriceOracle    | 0x78C12ccE8346B936117655Dd3D70a2501Fd3d6e6     |
| SfrxETHPriceOracle      | 0x8546A7C8C3C537914C3De24811070334568eF427     |
| EthXPriceOracle         | 0x3D08ccb47ccCde84755924ED6B0642F9aB30dFd2     |

### NodeDelegator Proxy Addresses
- NodeDelegator proxy index 0: 0x07b96Cf1183C9BFf2E43Acf0E547a8c4E4429473
- NodeDelegator proxy index 1: 0x429554411C8f0ACEEC899100D3aacCF2707748b3
- NodeDelegator proxy index 2: 0x92B4f5b9ffa1b5DB3b976E89A75E87B332E6e388
- NodeDelegator proxy index 3: 0x9d2Fc9287e1c3A1A814382B40AAB13873031C4ad
- NodeDelegator proxy index 4: 0xe8038228ff1aEfD007D7A22C9f08DDaadF8374E4


### Immutable Contracts
#### ETH Mainnet
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateProvider       | 0xF1cccBa5558D31628216489A1435e068b1fd2C8A     |
| OneETHPriceOracle       | 0x4cB8d6DCd56d6b371210E70837753F2a835160c4     |
| RSETHPriceFeed (Morph)  | 0x4B9C66c2C0d3706AabC6d00D2a6ffD2B68A4E383     |

#### Polygon ZKEVM
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver       |  0x4186BFC76E2E237523CBC30FD220FE055156b41F    |

