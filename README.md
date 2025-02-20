# LRT-ETH
Kelp DAO (https://www.kelpdao.xyz/restake/) is liquid restaking protocol currently building on top of EigenLayer.
It gives users access to multiple benefits like restaking rewards, staking rewards, DeFi and liquidity.

## Table of Content

- [LRT-ETH](#lrt-eth)
  - [Table of Content](#table-of-content)
- [Getting Started](#getting-started)
  - [Setup](#setup)
  - [Develop](#develop)
    - [Clean](#clean)
    - [Compile](#compile)
    - [Format](#format)
    - [Gas Usage](#gas-usage)
    - [Lint](#lint)
  - [Deploy](#deploy)
    - [setup](#setup-1)
    - [Deploy to testnet](#deploy-to-testnet)
    - [Deploy to Anvil:](#deploy-to-anvil)
    - [General Deploy Script Instructions](#general-deploy-script-instructions)
  - [Verify Contracts](#verify-contracts)
  - [Test](#test)
  - [Using Static Analyzer for the contracts](#using-static-analyzer-for-the-contracts)
- [Deployed Contracts](#deployed-contracts)
  - [Berachain c-artio testnet](#berachain-c-artio-testnet)
  - [ETH Mainnet](#eth-mainnet)
    - [NodeDelegator Proxy Addresses](#nodedelegator-proxy-addresses)
  - [Holesky](#holesky)
  - [Arbitrum](#arbitrum)
  - [Manta](#manta)
  - [Mode](#mode)
  - [Blast](#blast)
  - [Base](#base)
  - [Optimism](#optimism)
  - [Scroll](#scroll)
  - [Linea](#linea)
  - [X Layer](#x-layer)
  - [Zircuit](#zircuit)
  - [zkSync](#zksync)
  - [BSC](#bsc)
  - [Safe Multisigs](#safe-multisigs)
  - [Bridged RSETH](#bridged-rseth)
    - [CCIP (Chainlink) RSETH](#ccip-chainlink-rseth)
    - [LayerZero RSETH\_OFT](#layerzero-rseth_oft)
  - [Bridged KERNEL](#bridged-kernel)
    - [LayerZero KERNEL\_OFT](#layerzero-kernel_oft)
  - [RSETH Price/Rate Providers](#rseth-pricerate-providers)
    - [ETH Mainnet](#eth-mainnet-1)
    - [Arbitrum](#arbitrum-1)
    - [Optimism](#optimism-1)
    - [Polygon ZKEVM](#polygon-zkevm)
    - [Blast](#blast-1)
    - [Mode](#mode-1)
    - [Scroll](#scroll-1)
    - [Base](#base-1)
    - [Linea](#linea-1)
    - [X Layer](#x-layer-1)
    - [Zircuit](#zircuit-1)
    - [zkSync](#zksync-1)



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

### setup
import dev private key to cast, this will ask for pvt key and a password
```bash
cast wallet import devKey --interactive
```

add the public address of the wallet in `.env` file
```bash
DEV_PUB_ADDR=xxxx
```

### Deploy to testnet

```bash
make deploy-lrt-testnet
```

### Deploy to Anvil:

```bash
anvil --fork-url $MAINNET_RPC_URL // on terminal 2
make deploy-lrt-local-test // on terminal 1
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


# Deployed Contracts

## Berachain c-artio testnet
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| RSETH (Standard ERC20)  | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |

## ETH Mainnet
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x673a669425457bCabeb247f56552A0Fd8141cee2     |
| ProxyAdmin              | 0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78     |
| ProxyAdmin Owner        | 0x49bD9989E31aD35B0A62c20BE86335196A3135B1     |
| TimelockController      | 0x49bD9989E31aD35B0A62c20BE86335196A3135B1     |
| ProxyAdmin (Owner Safe Manager) |  0x7550eAEe86F649Dc5cbA74e92D3E2667b68753fa    |
| ProxyAdmin Owner        |  0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2    |
| ProxyAdmin (for L1VaultETH contracts) |  0x2155AB0b399A71DF8c464dFc1b02149b53b2b2c1    |
| TimelockController (for L1VaultETH contracts)  |  0x10e5631320A6e7898F1b18aEADE46Acc81deB869    |
| ProxyAdmin Owner        |  0x10e5631320A6e7898F1b18aEADE46Acc81deB869    |


| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| KERNEL                  | 0x3f80B1c54Ae920Be41a77f8B902259D48cf24cCf     |
| KernelDepositPool       | 0xc64CD976F81090A4b2320b42309fFE27ff9F690D     |
| KernelMerkleDistributor | 0x68B55c20A2634B25a50a219b632F22854D810bf5     |
| LRTConfig               | 0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7     |
| RSETH                   | 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7     |
| LRTDepositPool          | 0x036676389e48133B63a802f8635AD39E752D375D     |
| LRTOracle               | 0x349A73444b1a310BAe67ef67973022020d70020d     |
| ChainlinkPriceOracle    | 0x78C12ccE8346B936117655Dd3D70a2501Fd3d6e6     |
| SfrxETHPriceOracle      | 0x8546A7C8C3C537914C3De24811070334568eF427     |
| EthXPriceOracle         | 0x3D08ccb47ccCde84755924ED6B0642F9aB30dFd2     |
| SwETHPriceOracle        | 0xCB8f20a144bFA15066148A1F29F1091d15B25f93     |
| RETHPriceOracle         | 0x585839c360872731Fc271183b9F703654ce08275     |
| FeeReceiver             | 0xdbC3363De051550D122D9C623CBaff441AFb477C     |
| KelpEarnedPoint         | 0x8E3A59427B1D87Db234Dd4ff63B25E4BF94672f4     |
| KEP MerkleDistributor   | 0x2DDB11443bD9Ceb92d4951A05f55eb7096EB53d3     |
| EIGEN MerkleDistributor Season 1 (Not used anymore) | 0xc135b516e399C1ed702588D887FBBE6F2d1bA27A     |
| EIGEN MerkleDistributor Programatic EIGEN           | 0x9bB6d4b928645EdA8f9C019495695BA98969eFF1     |
| LRTConverter            | 0x598dbcb99711E5577fF76ef4577417197B939Dfa     |
| LRTWithdrawalManager    | 0x62De59c08eB5dAE4b7E6F7a8cAd3006d6965ec16     |
| LRTUnstakingVault       | 0xc66830E2667bc740c0BED9A71F18B14B8c8184bA     |
| L1VaultETH (Scroll)     | 0x32064a427e8bdF59B14AC169d9835168328A36a6     |
| L1VaultETH (Base)       | 0x48CdaD4C3c7A2F5818DAb5EB08dF7DB5420a60F6     |
| L1VaultETH (Arbitrum)   | 0x4B7b39793a84AB6EccdA80795733480E7d046bE8     |
| L1VaultETH (Optimism)   | 0x83d4B497dBE3BD2D42E0F3Ee5ab34f83E80Ab4E0     |
| L1VaultETH (Linea)      | 0x6224C582a0989cfEcd232Af28C68F446b46979EF     |
| L1VaultETH (zkSync)     | 0xdADB65FB1fcC3D877d774e5e2b00013fE1EFBF76     |
| AGETHMultiChainRateProvider | 0xc430c78Da6E4AF49bD115F0329D154Bb135f1363     |
| RSETH_OFTAdapter        | 0x85d456B2DfF1fd8245387C0BfB64Dfb700e98Ef3     |
| KERNEL_OFTAdapter       | 0x2A1D74de3027ccE18d31011518C571130a4cd513     |
| KernelVaultETH          | 0x1ee623b2ECE718571B0e1959410112081d4B4ebA     |

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

## Holesky
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0xB64646f2862ddB5f4f48f8559BA7a061F08DF168     |
| ProxyAdmin              | 0x835cCCC5cea5144FE1A0229918BB9A5e2ec88378     |
| ProxyAdmin Owner        | 0x5DB1955f51f892ce1bbEf3EcEC8a46b85fe75F27     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| LRTConfig               | 0x1b132cbc40d35170d8c46614Bc1C2282f458386F     |
| RSETH                   | 0xa0F9F6D5d6ef60D80517ADf3E8aB9D4E0A41557B     |
| LRTDepositPool          | 0xF8e4b7b81dAfd1C8642466aB1c12D37015Cc1AF7     |
| LRTOracle               | 0x6aA9cB27581F266Fd17895C7FB80cf22cF0B5C13     |
| EthXPriceOracle         | 0xB0cCa9916C90A651492C2c0f4f4ED2572FBF89A5     |
| FeeReceiver             | 0x7291045354054d51D273c6B027B866Da1D4B1600     |
| LRTConverter            | 0x70A217C5Ee3ba3c4Dc7a4Ca408606224bD81Ef96     |
| LRTWithdrawalManager    | 0xf9336F42A8C5DDdE48E148208687444C707542D5     |
| LRTUnstakingVault       | 0x3AA985382052769ac6d7D2FEE8f2FfA707AE9ab5     |

- NodeDelegator proxy index 0: 0x7fcDe9d78a094745eF1A104353cfbCc6496D1A2b
- NodeDelegator proxy index 1: 0x8d21C3dcdD520411C6640410BB6Fb8A47e87e5B5
- NodeDelegator proxy index 2: 0x039e8FBBd2791be6C8CbbfB891a592d53A085d83
- NodeDelegator proxy index 3: 0x412197B9bCDCeFD476f98870638B4b84014645ba
- NodeDelegator proxy index 4: 0x8F3E94Fb6e9a913041C777aDC0B1A8B02F92CeeF


## Arbitrum
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x81E5c1483c6869e95A4f5B00B41181561278179F     |
| ProxyAdmin              | 0x4938c803EBe999FB0A5527310662624f2E7A38C1     |
| ProxyAdmin Owner        | 0xe15109D97e84cacEd271502C5D1DBbC50A4D6B0C     |
| TimelockController      | 0xe15109D97e84cacEd271502C5D1DBbC50A4D6B0C     |
| Timelock Proposer       | 0x96D97D66d4290C9182A09470a5775FF90DAf922c     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHPool               | 0x376A7564AF88242D6B8598A5cfdD2E9759711B61     |
| AGETHRateReceiver       | 0x5435F5179717Ae0cdb6707BdA8184eE6b001C16b     |
| AGETHTokenWrapper       | 0xF1A88250532a4A66A2420a8cbB434Da82E1E2cA1     |
| AGETHPoolV3             | 0x77F5979D8eA6d72d6C6C451eC23c772D68211c5f     |

## Manta
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72     |
| ProxyAdmin              | 0x2B1CbD412565c0a2D32E62Ab7304bb464C644cc1     |
| ProxyAdmin Owner        | 0x84efef1439f1b6f264866f65062ba49df764be08     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       | 0x9dd4f9EeE9B05D1ebec1d4aAE7Ae9F5d8D235CD4     |

## Mode
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x30c2B5f5c74B855d99792E485bDBcE1dD2f2e1A9     |
| ProxyAdmin              | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72     |
| ProxyAdmin Owner        | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       | 0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd     |
| RSETHPoolV2             | 0xbDf612E616432AA8e8D7d8cC1A9c934025371c5C     |

## Blast
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x30c2B5f5c74B855d99792E485bDBcE1dD2f2e1A9     |
| ProxyAdmin              | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72     |
| ProxyAdmin Owner        | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       | 0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd     |
| RSETHPoolV2             | 0x1558959f1a032F83f24A14Ff539944A926C51bdf     |
| MerkleBlastPointsDistributor | 0xf7f6231C4092B3322f8b834379d9c73a49FdF67F|

## Base
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0xAd6626758Bd6d2e6f68Da203087248f59ca4fB97     |
| ProxyAdmin              | 0xDf3f5926Fd14Ed048B04941189da54BdEDD478d0     |
| ProxyAdmin Owner        | 0xf425ed48483B49cF10C8a7f6cFd25dFD86d3155a     |
| TimelockController      | 0xf425ed48483B49cF10C8a7f6cFd25dFD86d3155a     |
| Timelock Proposer       | 0x7Da95539762Dd11005889F6B72a6674A4888B56d     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       | 0xEDfa23602D0EC14714057867A78d01e94176BEA0     |
| RSETHPoolV2             | 0x291088312150482826b3A37d5A69a4c54DAa9118     |

## Optimism
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x5c6AB8B02b29cd205580C02681d27Cb6246eEFbc     |
| ProxyAdmin              | 0xa465eAfAfEE5629eE92832e14C37df4723816d58     |
| ProxyAdmin Owner        | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f     |
| TimelockController      | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f     |
| Timelock Proposer       | 0x0d30A563e38Fe2926b37783A046004A7869adE6C     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       | 0x87eEE96D50Fb761AD85B1c982d28A042169d61b1     |
| RSETHPoolV2             | 0xaAA687e218F9B53183A6AA9639FBD9D6e69EcB73     |

## Scroll
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x1373A61449C26CC3F48C1B4c547322eDAa36eB12     |
| ProxyAdmin              | 0xAD3B3ECd2130AaaB5f1fd9aEC82879Bd8D56742D     |
| ProxyAdmin Owner        | 0x37a6cfeD9199d4deccD01487bEA106C51c36a3C0     |
| TimelockController      | 0x37a6cfeD9199d4deccD01487bEA106C51c36a3C0     |
| Timelock Proposer       | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       | 0xa25b25548B4C98B0c7d3d27dcA5D5ca743d68b7F     |
| RSETHPoolV2             | 0xb80deaecd7F4Bca934DE201B11a8711644156a0a     |
| ScrollMessenger         | 0xf3a6Bcafc5639EA6cC01975Ee69FcD63F614fb08     |
| AGETHRateReceiver       | 0xc3eACf0612346366Db554C991D7858716db09f58     |
| AGETHTokenWrapper       | 0xd44605d3E5eF9A73379Ce5258B06e4383c6FF32a     |
| AGETHPoolV3             | 0x6c5513F8701a6E58C82D9a0585A2E533A7fC773b     |
| MerkleDistributor for Scroll Airdrop | 0xbE7E2d809E2C7405B5972292986324a798921D98 |

## Linea
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            | 0x4938c803EBe999FB0A5527310662624f2E7A38C1     |
| ProxyAdmin              | 0x352E20158C9916579b337d1332F462B26A8A699c     |
| ProxyAdmin Owner        | 0x6Fc178d2E40f47233960b8e784B64Dcc6ac556ac     |
| TimelockController      | 0x6Fc178d2E40f47233960b8e784B64Dcc6ac556ac     |
| Timelock Proposer       | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6     |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       | 0xD2671165570f41BBB3B0097893300b6EB6101E6C     |
| RSETHPoolV2             | 0x057297e44A3364139EDCF3e1594d6917eD7688c2     |
| AGETHRateReceiver       | 0x5435F5179717Ae0cdb6707BdA8184eE6b001C16b     |
| AGETHTokenWrapper       | 0x2a4f1dcc79b83608f9e3BC1F3F55fBEfCBFaE885     |
| AGETHPoolV3             | 0x7F260B785E3B74155a39d82251B47D05ae0d6c61     |

## X Layer
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            |   0xe119D214a6efa7d3cF60e6E59481EDe1B0064A6B   |
| ProxyAdmin              |   0x3222d3De5A9a3aB884751828903044CC4ADC627e   |
| ProxyAdmin Owner        |   0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6   |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       |   0x5A71f5888EE05B36Ded9149e6D32eE93812EE5e9   |
| RSETHPoolV3             |   0x4Ef626efE4a3A279a9DC7e7a91C1c9CaaAE8e159   |

| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| WETHOracle              |   0x6F27976308001119a8e89cB447333DaaA3043CE7   |

## Zircuit
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            |  0x352E20158C9916579b337d1332F462B26A8A699c    |
| ProxyAdmin              |  0x3E68B0b81b835a6a26A0C64b95E61aB2728260e6    |
| ProxyAdmin Owner        |  0x7AAd74b7f0d60D5867B59dbD377a71783425af47    |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       | 0x311a51Ff8839B6afcAA9426BdBffDF2e70A0dA25     |
| RSETHPoolV3             | 0xca276450b2c26061785CF11668dd481168E102Cb     |

## zkSync
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyAdmin              |  0xd836801C07e9b471Fa3c525bc13bC4333c51F25F    |
| ProxyAdmin Owner        |  0x2Aeb356f2bE90FA2C138B044144dd9946fC63573    |
| TimelockController      |  0x2Aeb356f2bE90FA2C138B044144dd9946fC63573    |
| Timelock Proposer       |  0xeD38DA849b20Fa27B07D073053C5F5aAe6A2dB6b    |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RsETHTokenWrapper       |  0xd4169E045bcF9a86cC00101225d9ED61D2F51af2    |
| RSETHPoolV2             |  0x41b300f5A619973b20931f0944C85DB229d5E27f    |

## BSC
| Contract Name           |  Address                                       |
|-------------------------|------------------------------------------------|
| ProxyFactory            |  0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f    |
| ProxyAdmin              |  0xE5ca826202846363ac1C3F04598a9fb3A85ed753    |
| ProxyAdmin Owner        |  0xb4222155CDB309Ecee1bA64d56c8bAb0475a95b0    |

| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| KernelDepositPool       | 0xdE1eF8104220A372B80771fE1C0f7944334e013B     |
| KernelMerkleDistributor | 0xA3770E27681F1A88575158faDB8CBd2b7D5489E6     |
| KernelReceiver          | 0x6b28ae299A9aFec9449f79f8a56F907fBD47E740     |


## Safe Multisigs

| Name                 | Safe Address                                   |
|----------------------|------------------------------------------------|
| ETH Mainnet Manager  | 0xCbcdd778AA25476F203814214dD3E9b9c46829A1     |
| ETH Mainnet Admin    | 0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2     |
| ETH Mainnet External Admin    | 0xb3696a817D01C8623E66D156B6798291fa10a46d    |
| ETH Mainnet Eigen    | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6     |
| BSC                  | 0xb4222155CDB309Ecee1bA64d56c8bAb0475a95b0     |
| Optimism             | 0x0d30A563e38Fe2926b37783A046004A7869adE6C     |
| Arbitrum             | 0x96D97D66d4290C9182A09470a5775FF90DAf922c     |
| Polygon ZKEVM        | 0x424Fc153C4005F8D5f23E08d94F5203D99E9B160     |
| Manta                | 0x84eFeF1439F1b6F264866F65062Ba49Df764bE08     |
| zkSync               | 0xeD38DA849b20Fa27B07D073053C5F5aAe6A2dB6b     |
| Base                 | 0x7Da95539762Dd11005889F6B72a6674A4888B56d     |
| Scroll               | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6     |
| Linea                | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6     |
| Blast                | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6     |
| X Layer               | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6    |
| X Layer (OFT Owner Safe)    |   0x449DEFBac8dc846fE51C6f0aBD92d0F1e1b2b3E5   |



## Bridged RSETH

### CCIP (Chainlink) RSETH
| Network      | Address                                        |
|--------------|------------------------------------------------|
| Arbitrum     | 0xe119D214a6efa7d3cF60e6E59481EDe1B0064A6B     |
| Optimism     | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72     |
| BSC          | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |

### LayerZero RSETH_OFT
| Network      | Address                                        |
|--------------|------------------------------------------------|
| Arbitrum     | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |
| Optimism     | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |
| Manta        | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |
| Mode         | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |
| Blast        | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |
| Scroll       | 0x65421ba909200b81640d98B979d07487C9781B66     |
| Base         | 0x1Bc71130A0e39942a7658878169764Bbd8A45993     |
| Linea        | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |
| X Layer       | 0x1B3a9A689Ba7555F9D7984D7Ad4025574Ed5A0f9    |
| zkSync       | 0x6bE2425C381eb034045b527780D2Bf4E21AB7236     |
| Zircuit      | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |
| Swell        | 0xc3eACf0612346366Db554C991D7858716db09f58     |
| Hemi         | 0xc3eACf0612346366Db554C991D7858716db09f58     |
| Bera         | 0x4186BFC76E2E237523CBC30FD220FE055156b41F     |


## Bridged KERNEL

### LayerZero KERNEL_OFT
| Network      | Address                                        |
|--------------|------------------------------------------------|
| BSC          | 0x9eCaf80c1303CCA8791aFBc0AD405c8a35e8d9f1     |
| Arbitrum     | 0x6E401189c8A68D05562c9Bab7f674f910821EAcF     |


## RSETH Price/Rate Providers
### ETH Mainnet
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHMultiChainRateProvider       | 0x0788906B19bA8f8d0e8a7015f0714DF3179D9aB6     |
| RSETHRateProvider       | 0xF1cccBa5558D31628216489A1435e068b1fd2C8A     |
| OneETHPriceOracle       | 0x4cB8d6DCd56d6b371210E70837753F2a835160c4     |
| RSETHPriceFeed (Morph)  | 0x4B9C66c2C0d3706AabC6d00D2a6ffD2B68A4E383     |

### Arbitrum
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x3222d3De5A9a3aB884751828903044CC4ADC627e     |

### Optimism
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x1373A61449C26CC3F48C1B4c547322eDAa36eB12     |

### Polygon ZKEVM
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver  (Uses RSETHRateProvider on ETH mainnet as provider)     |  0x4186BFC76E2E237523CBC30FD220FE055156b41F    |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       |  0x30CE1444834dbd91e23317179A39d875B16F0DCd    |

### Blast
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x38dd27B51E2E6868D99B615097c03A3DE7fa7AA8     |

### Mode
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x38dd27B51E2E6868D99B615097c03A3DE7fa7AA8     |

### Scroll
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0xc9BcFbB1Bf6dd20Ba365797c1Ac5d39FdBf095Da     |

### Base
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x7781ae9B47FeCaCEAeCc4FcA8d0b6187E3eF9ba7     |

### Linea
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x81E5c1483c6869e95A4f5B00B41181561278179F     |

### X Layer
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x30CE1444834dbd91e23317179A39d875B16F0DCd     |

### Zircuit
| Contract Name           | Proxy Address                                  |
|-------------------------|------------------------------------------------|
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x81E5c1483c6869e95A4f5B00B41181561278179F     |

### zkSync

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet)       | 0x6C2e862E7d03e1C9dDa1b30De69b201c7c52e3dB |