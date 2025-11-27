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
    - [Legacy NodeDelegator Proxy Addresses](#legacy-nodedelegator-proxy-addresses)
  - [Holesky](#holesky)
  - [Hoodi](#hoodi)
    - [NodeDelegator Proxy Addresses](#nodedelegator-proxy-addresses-1)
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
  - [Unichain](#unichain)
  - [TAC](#tac)
  - [Avalanche](#avalanche)
  - [Sonic](#sonic)
  - [Ink](#ink)
  - [Plasma](#plasma)
  - [Base Sepolia (TESTNET Contracts)](#base-sepolia-testnet-contracts)
  - [Safe Multisigs](#safe-multisigs)
  - [Pauser Safes](#pauser-safes)
  - [Bridged RSETH](#bridged-rseth)
    - [CCIP (Chainlink) RSETH (Old)](#ccip-chainlink-rseth-old)
    - [CCIP (Chainlink) RSETH (New)](#ccip-chainlink-rseth-new)
    - [LayerZero RSETH_OFT](#layerzero-rseth_oft)
  - [Bridged KERNEL](#bridged-kernel)
    - [LayerZero KERNEL_OFT](#layerzero-kernel_oft)
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
    - [Unichain](#unichain-1)
    - [TAC](#tac-1)
    - [Avalanche](#avalanche-1)
    - [Sonic](#sonic-1)
    - [Ink](#ink-1)
    - [Plasma](#plasma-1)

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
[Solidity Scripting](https://book.getfoundry.sh/guides/scripting-with-solidity) tutorial.

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

Generate test coverage with lcov report (you'll have to open the `./coverage/index.html` file in your browser, to do so
simply copy paste the path):

Permit to run bash script

```sh
$ chmod +x ./script/bash_scripts/coverage.sh
```

then run the command:

```
$ make create_coverage_report
```

or

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

| Contract Name          | Address                                    |
| ---------------------- | ------------------------------------------ |
| RSETH (Standard ERC20) | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |

## ETH Mainnet

| Contract Name                                                              | Address                                    |
| -------------------------------------------------------------------------- | ------------------------------------------ |
| ProxyFactory                                                               | 0x673a669425457bCabeb247f56552A0Fd8141cee2 |
| ProxyAdmin (owner: TimelockController)                                     | 0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78 |
| ProxyAdmin Owner                                                           | 0x49bD9989E31aD35B0A62c20BE86335196A3135B1 |
| TimelockController                                                         | 0x49bD9989E31aD35B0A62c20BE86335196A3135B1 |
| ProxyAdmin (owner: Admin Safe)                                             | 0x7550eAEe86F649Dc5cbA74e92D3E2667b68753fa |
| ProxyAdmin Owner                                                           | 0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2 |
| ProxyAdmin (for L1Vault contracts)                                         | 0x2155AB0b399A71DF8c464dFc1b02149b53b2b2c1 |
| TimelockController (for L1Vault contracts and RSETHMultiChainRateProvider) | 0x10e5631320A6e7898F1b18aEADE46Acc81deB869 |
| ProxyAdmin Owner                                                           | 0x10e5631320A6e7898F1b18aEADE46Acc81deB869 |
| Manager TimelockController                                                 | 0x1Fda02CF28F28a763d996AD5Ee37B9f1b608E674 |

| Contract Name                                          | Proxy Address                              |
| ------------------------------------------------------ | ------------------------------------------ |
| KERNEL                                                 | 0x3f80B1c54Ae920Be41a77f8B902259D48cf24cCf |
| KernelDepositPool                                      | 0xc64CD976F81090A4b2320b42309fFE27ff9F690D |
| KernelMerkleDistributor (Apr 14)                       | 0x68B55c20A2634B25a50a219b632F22854D810bf5 |
| KernelTop100MerkleDistributor (May 2025)               | 0xeAE64Ce4Cb8578B0284b1a3DC2a0DBF433ca0099 |
| KernelTop100MerkleDistributor (Jun 2025)               | 0x5A98D097A528209024794BE4247403b5A5c34bAB |
| KernelTop100MerkleDistributor (Season 2)               | 0x65C273F22548b8670AEd973e3189613438Df0DC8 |
| KernelTop100MerkleDistributor (July 14 vesting 2025)   | 0x5db8DcfB1a4fb0f41E4Aa0DA2FCE21EB93941a2c |
| KernelTop100MerkleDistributor (August 14 vesting 2025) | 0x2B1B971dFD6b23a1E80fe95FDD39a33Cd06ac450 |
| KernelTop100MerkleDistributor (Sep 14 vesting 2025)    | 0xD0d483B612634741dd3eDDe4D60E87AaBB946231 |
| KernelTop100MerkleDistributor (Oct 14 vesting 2025)    | 0xbaC4957Bb140c3b19E5c1151203e515a799a8Dfb |
| KernelTop100MerkleDistributor (Season 3)               | 0xA182277f7E71e6cEc28d8F4dc005727CDd9c0E84 |
| LRTConfig                                              | 0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7 |
| RSETH                                                  | 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7 |
| LRTDepositPool                                         | 0x036676389e48133B63a802f8635AD39E752D375D |
| LRTOracle                                              | 0x349A73444b1a310BAe67ef67973022020d70020d |
| ChainlinkPriceOracle                                   | 0x78C12ccE8346B936117655Dd3D70a2501Fd3d6e6 |
| SfrxETHPriceOracle                                     | 0x8546A7C8C3C537914C3De24811070334568eF427 |
| EthXPriceOracle                                        | 0x3D08ccb47ccCde84755924ED6B0642F9aB30dFd2 |
| SwETHPriceOracle                                       | 0xCB8f20a144bFA15066148A1F29F1091d15B25f93 |
| RETHPriceOracle                                        | 0x585839c360872731Fc271183b9F703654ce08275 |
| FeeReceiver                                            | 0xdbC3363De051550D122D9C623CBaff441AFb477C |
| TokenSwap(swap KERNEL and EIGEN for KING)              | 0xD487d060E4ED5931F956362a5b5FF36CA837DCee |
| KelpEarnedPoint                                        | 0x8E3A59427B1D87Db234Dd4ff63B25E4BF94672f4 |
| KEP MerkleDistributor                                  | 0x2DDB11443bD9Ceb92d4951A05f55eb7096EB53d3 |
| EIGEN MerkleDistributor Season 2 (Not used anymore)    | 0xc135b516e399C1ed702588D887FBBE6F2d1bA27A |
| EIGEN MerkleDistributor Programatic EIGEN              | 0x9bB6d4b928645EdA8f9C019495695BA98969eFF1 |
| LRTConverter                                           | 0x598dbcb99711E5577fF76ef4577417197B939Dfa |
| LRTWithdrawalManager                                   | 0x62De59c08eB5dAE4b7E6F7a8cAd3006d6965ec16 |
| LRTUnstakingVault                                      | 0xc66830E2667bc740c0BED9A71F18B14B8c8184bA |
| UnlockedWithdrawalsInitializer                         | 0xa9B1CED1839bA07c4E8AaEF45BB60c8B27B35595 |
| L1Vault (Scroll)                                       | 0x32064a427e8bdF59B14AC169d9835168328A36a6 |
| L1Vault (Base)                                         | 0x48CdaD4C3c7A2F5818DAb5EB08dF7DB5420a60F6 |
| L1Vault (Arbitrum)                                     | 0x4B7b39793a84AB6EccdA80795733480E7d046bE8 |
| L1Vault (Optimism)                                     | 0x83d4B497dBE3BD2D42E0F3Ee5ab34f83E80Ab4E0 |
| L1Vault (Linea)                                        | 0x6224C582a0989cfEcd232Af28C68F446b46979EF |
| L1Vault (zkSync)                                       | 0xdADB65FB1fcC3D877d774e5e2b00013fE1EFBF76 |
| L1Vault (Unichain) - not used yet                      | 0x085932450708CCf8E40Ad4EC2e4a10f78Fc379e8 |
| L1Vault (TAC) - not used yet                           | 0x4bd8727C366eB90f0F8fd5a1c6C452D475E88ea9 |
| L1Vault (Avalanche) - not used yet                     | 0xA0FeeE3ff245bf60529338Ef8F1DE3f6Fb7f676C |
| L1Vault (Sonic) - not used yet                         | 0x16e749dD40D93401BCa12E978882f571Fed63706 |
| L1Vault (Ink) - not used yet                           | 0xa9f6378704819Db0273cD9E3DF3C0Fe8F936FCd9 |
| L1Vault (Plasma) - not used yet                        | 0xbFB17749cbaa0732C70eD26b2dfdC5F664dE391F |
| AGETHMultiChainRateProvider                            | 0xc430c78Da6E4AF49bD115F0329D154Bb135f1363 |
| KernelVaultETH                                         | 0x1ee623b2ECE718571B0e1959410112081d4B4ebA |

### NodeDelegator Proxy Addresses

| Proxy Index | Address                                    | Notes          |
| ----------- | ------------------------------------------ | -------------- |
| 0           | 0xFc561966ceaAa09f4d6CBa4AdD54778c2bF1cB85 |                |
| 1           | 0x395884D1974a839702bcFCBa176AC7871c788946 | Luganodes      |
| 2           | 0x79f17234746344E0365D40be50d8d43DB9082c32 | P2P            |
| 3           | 0x4C798C4653b1257D5149910523D7a6eeD5712F83 |                |
| 4           | 0xee5470E1519972C3eA95249d60EBD064af2D53D3 |                |
| 5           | 0x049EA11D337f185b1Aa910d98e8Fbd991f0FBA7B | Allnodes/Pier2 |
| 6           | 0x545D69B99759E7b670Df243b882700121d6d3AB9 | Kiln           |

### Legacy NodeDelegator Proxy Addresses

0x07b96Cf1183C9BFf2E43Acf0E547a8c4E4429473\
0x429554411C8f0ACEEC899100D3aacCF2707748b3\
0x92B4f5b9ffa1b5DB3b976E89A75E87B332E6e388\
0x9d2Fc9287e1c3A1A814382B40AAB13873031C4ad\
0xe8038228ff1aEfD007D7A22C9f08DDaadF8374E4

## Holesky

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x65421ba909200b81640d98B979d07487C9781B66 |
| ProxyAdmin       | 0x1Bc71130A0e39942a7658878169764Bbd8A45993 |
| ProxyAdmin Owner | 0x5DB1955f51f892ce1bbEf3EcEC8a46b85fe75F27 |

| Contract Name        | Proxy Address                              |
| -------------------- | ------------------------------------------ |
| LRTConfig            | 0x1b132cbc40d35170d8c46614Bc1C2282f458386F |
| RSETH                | 0xa0F9F6D5d6ef60D80517ADf3E8aB9D4E0A41557B |
| LRTDepositPool       | 0xF8e4b7b81dAfd1C8642466aB1c12D37015Cc1AF7 |
| LRTOracle            | 0x6aA9cB27581F266Fd17895C7FB80cf22cF0B5C13 |
| EthXPriceOracle      | 0xB0cCa9916C90A651492C2c0f4f4ED2572FBF89A5 |
| FeeReceiver          | 0x7291045354054d51D273c6B027B866Da1D4B1600 |
| LRTConverter         | 0x70A217C5Ee3ba3c4Dc7a4Ca408606224bD81Ef96 |
| LRTWithdrawalManager | 0xf9336F42A8C5DDdE48E148208687444C707542D5 |
| LRTUnstakingVault    | 0x3AA985382052769ac6d7D2FEE8f2FfA707AE9ab5 |

- NodeDelegator proxy index 0: 0x7fcDe9d78a094745eF1A104353cfbCc6496D1A2b
- NodeDelegator proxy index 1: 0x8d21C3dcdD520411C6640410BB6Fb8A47e87e5B5
- NodeDelegator proxy index 2: 0x039e8FBBd2791be6C8CbbfB891a592d53A085d83
- NodeDelegator proxy index 3: 0x412197B9bCDCeFD476f98870638B4b84014645ba
- NodeDelegator proxy index 4: 0x8F3E94Fb6e9a913041C777aDC0B1A8B02F92CeeF

## Hoodi

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x65421ba909200b81640d98b979d07487c9781b66 |
| ProxyAdmin       | 0x1bc71130a0e39942a7658878169764bbd8a45993 |
| ProxyAdmin Owner | 0x5db1955f51f892ce1bbef3ecec8a46b85fe75f27 |

| Contract Name        | Proxy Address                              |
| -------------------- | ------------------------------------------ |
| RSETH                | 0x335a87203F39E9134FBB336E73629bF0822bA371 |
| LRTConfig            | 0x0B4aCEf96828F28BbEBc6a0E5C5C6b2c84919a6b |
| LRTOracle            | 0xC114805227947248153478a10638d8E0E93CdFc5 |
| LRTDepositPool       | 0x44167e2db805fEB0Eca440F695Dc0BF5679Bd1A8 |
| LRTWithdrawalManager | 0xeB26b4108d216e78D1Ea4C136689d8c8F7E59c0B |
| LRTUnstakingVault    | 0x2617d76B8454db6AeBB27396e825F9B46e79ccB4 |
| LRTConverter         | 0x5E0dA2B4C9AC128C70398F268bF71DAd2E09eA71 |
| RewardReceiver       | 0xE2d1a7ADcC3f9920B4aF2Bf0Ee9a01D6FF21ef47 |
| ProtocolTreasury     | 0x5DB1955f51f892ce1bbEf3EcEC8a46b85fe75F27 |
| PubkeyRegistry       | 0x5C94Da6a53a61F5384d19723b7580E9d76667cc4 |
| OneETHPriceOracle    | 0x8B9991f89Fc31600DCE064566ccE28dC174Fb8E4 |
| FeeReceiver          | 0x4c0a04F3cD214fbf25936a0C459299d6DE105312 |

### NodeDelegator Proxy Addresses

| Proxy Index | Address                                    |
| ----------- | ------------------------------------------ |
| 0           | 0x5Bd85f9174ac689C3Fe04D3485495B96EDB67635 |
| 1           | 0x44847e6B4B12d01AF8D21890fED06440BcE2783b |
| 2           | 0x897cEe19CaeC34eF4992531a2a783A805239F100 |
| 3           | 0x38F3e18111f9071d69B2AE9049fAFaad3946f63a |
| 4           | 0xf317cC4956520698d894f5957028230c6A8c2115 |

## Arbitrum

| Contract Name             | Address                                          |
| ------------------------- | ------------------------------------------------ |
| ProxyFactory              | 0x81E5c1483c6869e95A4f5B00B41181561278179F       |
| ProxyAdmin                | 0x4938c803EBe999FB0A5527310662624f2E7A38C1       |
| ProxyAdmin Owner          | 0xe15109D97e84cacEd271502C5D1DBbC50A4D6B0C       |
| TimelockController        | 0xe15109D97e84cacEd271502C5D1DBbC50A4D6B0C       |
| Timelock Proposer         | 0x96D97D66d4290C9182A09470a5775FF90DAf922c       |
| ------------------------- | ------------------------------------------------ |

| OffchainConfig Contracts
|-------------------------|------------------------------------------------|
| ProxyFactory | 0xe0c1211c487215E86311138130261A587D5C5496 |
| ProxyAdmin | 0x583cD15A946B79f7Cccab62346445192DCDd5cf0 |
| ProxyAdmin Owner | 0x96D97D66d4290C9182A09470a5775FF90DAf922c |
| OffchainConfig Mainnet | 0xAA1BEd0d59fDF11f5f302EB927DF091528763702 |
| OffchainConfig Testnet | 0x2F6da2f68dDECFAdd721912b3d9D316e55Bb8019 |

| Contract Name      | Proxy Address                              |
| ------------------ | ------------------------------------------ |
| RSETHPool          | 0x376A7564AF88242D6B8598A5cfdD2E9759711B61 |
| ArbitrumMessenger  | 0x58439F875CbfAA81B94CeA89a934B6108bdec9f7 |
| ArbitrumLidoBridge | 0x23e74e86bE143E427f5aA6F5410D322a8DBE0aC7 |
| wstETH Oracle      | 0x6932e85964fA31F70ed9DEbe63D9D969ad00F112 |
| ETHx Oracle        | 0x0c742a74fA8E1a00D6bC4623d485A84dD147864d |
| HashStorage        | 0x141F6c276D7a1937603667C72a7688Edbda16728 |
| AGETHRateReceiver  | 0x5435F5179717Ae0cdb6707BdA8184eE6b001C16b |
| AGETHTokenWrapper  | 0xF1A88250532a4A66A2420a8cbB434Da82E1E2cA1 |
| AGETHPoolV3        | 0x77F5979D8eA6d72d6C6C451eC23c772D68211c5f |

## Manta

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72 |
| ProxyAdmin       | 0x2B1CbD412565c0a2D32E62Ab7304bb464C644cc1 |
| ProxyAdmin Owner | 0x84efef1439f1b6f264866f65062Ba49df764be08 |

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

| Contract Name                | Proxy Address                              |
| ---------------------------- | ------------------------------------------ |
| RsETHTokenWrapper            | 0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd |
| RSETHPoolV2                  | 0x1558959f1a032F83f24A14Ff539944A926C51bdf |
| MerkleBlastPointsDistributor | 0xf7f6231C4092B3322f8b834379d9c73a49FdF67F |

## Base

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0xAd6626758Bd6d2e6f68Da203087248f59ca4fB97 |
| ProxyAdmin         | 0xDf3f5926Fd14Ed048B04941189da54BdEDD478d0 |
| ProxyAdmin Owner   | 0xf425ed48483B49cF10C8a7f6cFd25dFD86d3155a |
| TimelockController | 0xf425ed48483B49cF10C8a7f6cFd25dFD86d3155a |
| Timelock Proposer  | 0x7Da95539762Dd11005889F6B72a6674A4888B56d |

| Contract Name                           | Proxy Address                              |
| --------------------------------------- | ------------------------------------------ |
| RsETHTokenWrapper                       | 0xEDfa23602D0EC14714057867A78d01e94176BEA0 |
| RSETHPoolV3ExternalBridge               | 0x291088312150482826b3A37d5A69a4c54DAa9118 |
| Base LidoBridge                         | 0x503d45c009F81142556919A3cd0df91E097B3f0e |
| wstETH Oracle                           | 0xEFbBf9290cDA1c3046211D5464CC52Dae46C544C |
| HashStorage (for proven withdrawals)    | 0xa7D877332230Ee1d8af941cA6EF9217BE6B6762E |
| HashStorage (for finalized withdrawals) | 0xfdeF98b5EC29Ce9C68800bAc608f8273979bbC0a |

## Optimism

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0x5c6AB8B02b29cd205580C02681d27Cb6246eEFbc |
| ProxyAdmin         | 0xa465eAfAfEE5629eE92832e14C37df4723816d58 |
| ProxyAdmin Owner   | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f |
| TimelockController | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f |
| Timelock Proposer  | 0x0d30A563e38Fe2926b37783A046004A7869adE6C |

| Contract Name             | Proxy Address                              |
| ------------------------- | ------------------------------------------ |
| RsETHTokenWrapper         | 0x87eEE96D50Fb761AD85B1c982d28A042169d61b1 |
| RSETHPoolV2ExternalBridge | 0xaAA687e218F9B53183A6AA9639FBD9D6e69EcB73 |

## Scroll

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0x1373A61449C26CC3F48C1B4c547322eDAa36eB12 |
| ProxyAdmin         | 0xAD3B3ECd2130AaaB5f1fd9aEC82879Bd8D56742D |
| ProxyAdmin Owner   | 0x37a6cfeD9199d4deccD01487bEA106C51c36a3C0 |
| TimelockController | 0x37a6cfeD9199d4deccD01487bEA106C51c36a3C0 |
| Timelock Proposer  | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6 |

| Contract Name                        | Proxy Address                              |
| ------------------------------------ | ------------------------------------------ |
| RsETHTokenWrapper                    | 0xa25b25548B4C98B0c7d3d27dcA5D5ca743d68b7F |
| RSETHPoolV2                          | 0xb80deaecd7F4Bca934DE201B11a8711644156a0a |
| ScrollMessenger                      | 0xf3a6Bcafc5639EA6cC01975Ee69FcD63F614fb08 |
| AGETHRateReceiver                    | 0xc3eACf0612346366Db554C991D7858716db09f58 |
| AGETHTokenWrapper                    | 0xd44605d3E5eF9A73379Ce5258B06e4383c6FF32a |
| AGETHPoolV3                          | 0x6c5513F8701a6E58C82D9a0585A2E533A7fC773b |
| MerkleDistributor for Scroll Airdrop | 0xbE7E2d809E2C7405B5972292986324a798921D98 |

## Linea

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0x4938c803EBe999FB0A5527310662624f2E7A38C1 |
| ProxyAdmin         | 0x352E20158C9916579b337d1332F462B26A8A699c |
| ProxyAdmin Owner   | 0x6Fc178d2E40f47233960b8e784B64Dcc6ac556ac |
| TimelockController | 0x6Fc178d2E40f47233960b8e784B64Dcc6ac556ac |
| Timelock Proposer  | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6 |

| Contract Name             | Proxy Address                              |
| ------------------------- | ------------------------------------------ |
| RsETHTokenWrapper         | 0xD2671165570f41BBB3B0097893300b6EB6101E6C |
| RSETHPoolV2ExternalBridge | 0x057297e44A3364139EDCF3e1594d6917eD7688c2 |
| LineaMessenger            | 0x838686d23521435B528F68Cde6404C07ae007299 |
| HashStorage               | 0x02591eB906282Ef44135b4793f7adD0A14d0C618 |
| AGETHRateReceiver         | 0x5435F5179717Ae0cdb6707BdA8184eE6b001C16b |
| AGETHTokenWrapper         | 0x2a4f1dcc79b83608f9e3BC1F3F55fBEfCBFaE885 |
| AGETHPoolV3               | 0x7F260B785E3B74155a39d82251B47D05ae0d6c61 |

## X Layer

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0xe119D214a6efa7d3cF60e6E59481EDe1B0064A6B |
| ProxyAdmin       | 0x3222d3De5A9a3aB884751828903044CC4ADC627e |
| ProxyAdmin Owner | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0x5A71f5888EE05B36Ded9149e6D32eE93812EE5e9 |
| RSETHPoolV3       | 0x4Ef626efE4a3A279a9DC7e7a91C1c9CaaAE8e159 |

| Contract Name | Address                                    |
| ------------- | ------------------------------------------ |
| WETHOracle    | 0x6F27976308001119a8e89cB447333DaaA3043CE7 |

## Zircuit

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0x352E20158C9916579b337d1332F462B26A8A699c |
| ProxyAdmin         | 0x3E68B0b81b835a6a26A0C64b95E61aB2728260e6 |
| ProxyAdmin Owner   | 0xE5ca826202846363ac1C3F04598a9fb3A85ed753 |
| TimelockController | 0xE5ca826202846363ac1C3F04598a9fb3A85ed753 |
| Timelock Proposer  | 0x7AAd74b7f0d60D5867B59dbD377a71783425af47 |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0x311a51Ff8839B6afcAA9426BdBffDF2e70A0dA25 |
| RSETHPoolV3       | 0xca276450b2c26061785CF11668dd481168E102Cb |

## zkSync

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyAdmin         | 0xd836801C07e9b471Fa3c525bc13bC4333c51F25F |
| ProxyAdmin Owner   | 0x2Aeb356f2bE90FA2C138B044144dd9946fC63573 |
| TimelockController | 0x2Aeb356f2bE90FA2C138B044144dd9946fC63573 |
| Timelock Proposer  | 0xeD38DA849b20Fa27B07D073053C5F5aAe6A2dB6b |

| Contract Name     | Proxy Address                              |
| ----------------- | ------------------------------------------ |
| RsETHTokenWrapper | 0xd4169E045bcF9a86cC00101225d9ED61D2F51af2 |
| RSETHPoolV2       | 0x41b300f5A619973b20931f0944C85DB229d5E27f |
| HashStorage       | 0x2245AC63eA03f18D1a73BA6Ee3C4718b397fE726 |

## BSC

| Contract Name    | Address                                    |
| ---------------- | ------------------------------------------ |
| ProxyFactory     | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f |
| ProxyAdmin       | 0xE5ca826202846363ac1C3F04598a9fb3A85ed753 |
| ProxyAdmin Owner | 0xb4222155CDB309Ecee1bA64d56c8bAb0475a95b0 |

| Contract Name                            | Proxy Address                              |
| ---------------------------------------- | ------------------------------------------ |
| KernelDepositPool                        | 0xdE1eF8104220A372B80771fE1C0f7944334e013B |
| KernelMerkleDistributor                  | 0xA3770E27681F1A88575158faDB8CBd2b7D5489E6 |
| KernelReceiver                           | 0x6b28ae299A9aFec9449f79f8a56F907fBD47E740 |
| KernelTop100MerkleDistributor (Season 2) | 0x697a6343523323F6978e1eEd910a1FbCb7Aacd8e |
| KernelTop100MerkleDistributor (Season 3) | 0xc405487eb3a42651E174586f7F38856cC19E9976 |

## Unichain

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0xa321D2A72DB265c04d5C1318Ed69a719681bBAdE |
| ProxyAdmin         | 0x5aFDa76893CB7f9dE170B59D34f5E95dB5aDC4E0 |
| ProxyAdmin Owner   | 0x1237D9538b400233D876BF7cbEFa3e5b1D9e62C0 |
| TimelockController | 0x1237D9538b400233D876BF7cbEFa3e5b1D9e62C0 |
| Timelock Proposer  | 0x9Fc47d6A2F5A1EFd8BaF475E1873c76D9b28dDFD |

| Contract Name                           | Proxy Address                              |
| --------------------------------------- | ------------------------------------------ |
| RSETHPoolNoWrapper                      | 0xeCB98C5A390EFE3a3ad02b804e5c3E568e9D5f0f |
| UnichainMessenger                       | 0xfcF00f74EECc9864d4142474Cd530De33F7BDa48 |
| Unichain LidoBridge                     | 0xB95D5A07b925681452Dfa66B4cE17941E5a7C84e |
| HashStorage (for proven withdrawals)    | 0x2A2F37D29143AEa599c57169817A48c04664150b |
| HashStorage (for finalized withdrawals) | 0x37a6cfeD9199d4deccD01487bEA106C51c36a3C0 |
| InterimRSETHOracle                      | 0xF406c42b53B204e5ddEDcf33B5B25967d8D59A5e |

## TAC

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0x1B3a9A689Ba7555F9D7984D7Ad4025574Ed5A0f9 |
| ProxyAdmin         | 0xf3a6Bcafc5639EA6cC01975Ee69FcD63F614fb08 |
| ProxyAdmin Owner   | 0xa321D2A72DB265c04d5C1318Ed69a719681bBAdE |
| TimelockController | 0xa321D2A72DB265c04d5C1318Ed69a719681bBAdE |
| Timelock Proposer  | 0x3DA6b24D9003228356f7040f6e6b1fa5757C7a2c |

| Contract Name      | Proxy Address                              |
| ------------------ | ------------------------------------------ |
| RsETHTokenWrapper  | 0x5448BBf60Ee2edBCd32F032f3294982f4ad1119e |
| RSETHPoolV3        | 0x454CB45b309ee9798728168bA0244B496C1F98b8 |
| WETHOracle         | 0x5b5e596E417aeBa8075893f8B100eB8569e09C19 |
| InterimRSETHOracle | 0x5c08Bbc2C47447854958060725e437E6Dd003332 |

## Avalanche

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f |
| ProxyAdmin         | 0x9A7fA6fE70F2A23dc3980DF69f922b6961FbbE81 |
| ProxyAdmin Owner   | 0xF406c42b53B204e5ddEDcf33B5B25967d8D59A5e |
| TimelockController | 0xF406c42b53B204e5ddEDcf33B5B25967d8D59A5e |
| Timelock Proposer  | 0xB2Bb1425514Ab5903BE6bBDb6b44958e71103561 |

| Contract Name      | Proxy Address                              |
| ------------------ | ------------------------------------------ |
| RsETHTokenWrapper  | 0x7bFd4CA2a6Cf3A3fDDd645D10B323031afe47FF0 |
| RSETHPoolV3        | 0x72FB3F4F0B3cD77eF7556fa4960bF4aEBAA47009 |
| WETHOracle         | 0x5663ea61Dd44986bB92fCA764d1bE02bde08399A |
| InterimRSETHOracle | 0x3737e159c48991E37C200918Eba673ee48Ee9A0c |

## Sonic

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0xD9975bf0e147Dae42bbF6fb273455dcC328e378E |
| ProxyAdmin         | 0x1B3a9A689Ba7555F9D7984D7Ad4025574Ed5A0f9 |
| ProxyAdmin Owner   | 0xf3a6Bcafc5639EA6cC01975Ee69FcD63F614fb08 |
| TimelockController | 0xf3a6Bcafc5639EA6cC01975Ee69FcD63F614fb08 |
| Timelock Proposer  | 0xCbcdd778AA25476F203814214dD3E9b9c46829A1 |

| Contract Name                                 | Proxy Address                              |
| --------------------------------------------- | ------------------------------------------ |
| InterimRSETHOracle                            | 0x30c2B5f5c74B855d99792E485bDBcE1dD2f2e1A9 |
| WETHOracle                                    | 0x6daf987d3486C65Ff5Bc1c5aE40fa50B6349C132 |
| RSETHPoolV3WithNativeChainBridge              | 0x6189918EF83A73a9CD97BBff0d91af6ADCc9841D |
| RsETHTokenWrapper                             | 0x7c050Be1Dded733BD44116b60A8a35125ba47459 |
| SonicChainNativeTokenBridge                   | 0x7C39d591005b580df6CB63EFfCd0872AF0f48c8D |
| SonicBridgeReceiver (deployed on ETH mainnet) | 0x7C39d591005b580df6CB63EFfCd0872AF0f48c8D |
| HashStorage                                   | 0x50c81797Bf5d8B71f2815090B7f3e8cd44701af3 |

## Ink

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0x74Ef71709F2B97C382e1C06F35E063Ee0b4c196b |
| ProxyAdmin         | 0xdE06f1f1D0b152267310feE249F9167990E484cb |
| ProxyAdmin Owner   | 0xc430c78Da6E4AF49bD115F0329D154Bb135f1363 |
| TimelockController | 0xc430c78Da6E4AF49bD115F0329D154Bb135f1363 |
| Timelock Proposer  | 0x7a1112494843d0228BFFBa13eF3Ce57f4c35a461 |

| Contract Name      | Proxy Address                              |
| ------------------ | ------------------------------------------ |
| RsETHTokenWrapper  | 0x9f0a74A92287E323Eb95c1cd9eCdBEb0e397cAe4 |
| RSETHPoolV3        | 0xcD464f47Cb8AEd70F7e85dd5eca20Db021B5246B |
| InterimRSETHOracle | 0x1237D9538b400233D876BF7cbEFa3e5b1D9e62C0 |

## Plasma

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0xd0AC0bB79DF4043A7ddDa4E61506Da382174536f |
| ProxyAdmin         | 0x1237D9538b400233D876BF7cbEFa3e5b1D9e62C0 |
| ProxyAdmin Owner   | 0x5aFDa76893CB7f9dE170B59D34f5E95dB5aDC4E0 |
| TimelockController | 0x5aFDa76893CB7f9dE170B59D34f5E95dB5aDC4E0 |
| Timelock Proposer  | 0x5Ae348Bb75bC9587290a28636187B840E1F5dca2 |

| Contract Name      | Proxy Address                              |
| ------------------ | ------------------------------------------ |
| RsETHTokenWrapper  | 0xe561FE05C39075312Aa9Bc6af79DdaE981461359 |
| RSETHPoolV3        | 0xd59d17b0503b45F365670bDe9D002B9886EBC02b |
| WETHOracle         | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f |
| InterimRSETHOracle | 0xE5ca826202846363ac1C3F04598a9fb3A85ed753 |

## Base Sepolia (TESTNET Contracts)

| Contract Name      | Address                                    |
| ------------------ | ------------------------------------------ |
| ProxyFactory       | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f |
| ProxyAdmin         | 0xE5ca826202846363ac1C3F04598a9fb3A85ed753 |
| ProxyAdmin Owner   | 0xa321D2A72DB265c04d5C1318Ed69a719681bBAdE |
| TimelockController | 0xa321D2A72DB265c04d5C1318Ed69a719681bBAdE |
| Timelock Proposer  | 0x80Ec1075CEEF03E0Be63e328f5A1F97685bD0792 |

## Safe Multisigs

| Name                              | Safe Address                               |
| --------------------------------- | ------------------------------------------ |
| ETH Mainnet Manager               | 0xCbcdd778AA25476F203814214dD3E9b9c46829A1 |
| ETH Mainnet Admin                 | 0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2 |
| ETH Mainnet External Admin        | 0xb3696a817D01C8623E66D156B6798291fa10a46d |
| ETH Mainnet Eigen                 | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6 |
| KELP ETH Mainnet ProtocolTreasury | 0x322F2d4bFe8280EeB713B7C51EEbA42590C36f78 |
| ETH Dev                           | 0x8D5127aB6221F7c99a29294AC5F6A09ED322ac1E |
| BSC                               | 0xb4222155CDB309Ecee1bA64d56c8bAb0475a95b0 |
| Optimism                          | 0x0d30A563e38Fe2926b37783A046004A7869adE6C |
| Arbitrum                          | 0x96D97D66d4290C9182A09470a5775FF90DAf922c |
| Arbitrum (OffchainConfig Safe)    | 0xd4481D595D99E2BA0E3eDFBd65fBB79be50DAc5B |
| Polygon ZKEVM                     | 0x424Fc153C4005F8D5f23E08d94F5203D99E9B160 |
| Manta                             | 0x84eFeF1439F1b6F264866F65062Ba49Df764bE08 |
| zkSync                            | 0xeD38DA849b20Fa27B07D073053C5F5aAe6A2dB6b |
| Base                              | 0x7Da95539762Dd11005889F6B72a6674A4888B56d |
| Scroll                            | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6 |
| Linea                             | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6 |
| Blast                             | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6 |
| X Layer                           | 0xEe68dF9f661da6ED968Ea4cbF7EC68fcFE375bc6 |
| X Layer (OFT Owner Safe)          | 0x449DEFBac8dc846fE51C6f0aBD92d0F1e1b2b3E5 |
| Unichain                          | 0x9Fc47d6A2F5A1EFd8BaF475E1873c76D9b28dDFD |
| TAC                               | 0x3DA6b24D9003228356f7040f6e6b1fa5757C7a2c |
| Avalanche                         | 0xB2Bb1425514Ab5903BE6bBDb6b44958e71103561 |
| Sonic                             | 0xCbcdd778AA25476F203814214dD3E9b9c46829A1 |
| Ink                               | 0x7a1112494843d0228BFFBa13eF3Ce57f4c35a461 |
| Plasma                            | 0x5Ae348Bb75bC9587290a28636187B840E1F5dca2 |
| Base Sepolia                      | 0x80Ec1075CEEF03E0Be63e328f5A1F97685bD0792 |

## Pauser Safes

| Name        | Safe Address                               |
| ----------- | ------------------------------------------ |
| ETH Mainnet | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| BSC         | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Arbitrum    | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Optimism    | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Base        | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Linea       | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Scroll      | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Unichain    | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Sonic       | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Avalanche   | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| X Layer     | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Berachain   | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Ink         | 0xb6AbB489aCA4583833230F10B3A7670114D09559 |
| Plasma      | 0x789565f3Ee6a98cE003f7aF900dc50476aa7e49A |
| zkSync      | 0x4F472e76EC322FDfa4011Ae0D7cD8Cabb947D270 |
| TAC         | 0x814abDCAe834336bcDD2b8b490b18ea6Baa5B878 |

## Bridged RSETH

### CCIP (Chainlink) RSETH (Old)

| Network  | Address                                    |
| -------- | ------------------------------------------ |
| Arbitrum | 0xe119D214a6efa7d3cF60e6E59481EDe1B0064A6B |
| Optimism | 0x68A9EC5b93F04a60c77F486a664f283B2E4E2B72 |
| BSC      | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |

### CCIP (Chainlink) RSETH (New)

| Network  | Address                                    |
| -------- | ------------------------------------------ |
| Linea    | 0xb999Ea589E0a1Cce9153601daC2D6e203c2fD577 |
| Optimism | 0x043849686EE254ada46A432770E1a491491FC44D |
| Zircuit  | 0x571405D597091e8728d8240F558BAc01275E8659 |

### LayerZero RSETH_OFT

| Network                   | Address                                    |
| ------------------------- | ------------------------------------------ |
| Ethereum RSETH_OFTAdapter | 0x85d456B2DfF1fd8245387C0BfB64Dfb700e98Ef3 |
| Arbitrum                  | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Optimism                  | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Manta                     | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Mode                      | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Blast                     | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Scroll                    | 0x65421ba909200b81640d98B979d07487C9781B66 |
| Base                      | 0x1Bc71130A0e39942a7658878169764Bbd8A45993 |
| Linea                     | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| X Layer                   | 0x1B3a9A689Ba7555F9D7984D7Ad4025574Ed5A0f9 |
| zkSync                    | 0x6bE2425C381eb034045b527780D2Bf4E21AB7236 |
| Zircuit                   | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Swellchain                | 0xc3eACf0612346366Db554C991D7858716db09f58 |
| Hemi                      | 0xc3eACf0612346366Db554C991D7858716db09f58 |
| Berachain                 | 0x4186BFC76E2E237523CBC30FD220FE055156b41F |
| Sonic                     | 0xd75787bA9ABa324420d522BdA84c08c87e5099b1 |
| HyperEVM                  | 0xa321D2A72DB265c04d5C1318Ed69a719681bBAdE |
| Unichain                  | 0xc3eACf0612346366Db554C991D7858716db09f58 |
| TAC                       | 0x9eCaf80c1303CCA8791aFBc0AD405c8a35e8d9f1 |
| Avalanche                 | 0xc430c78Da6E4AF49bD115F0329D154Bb135f1363 |
| Ink                       | 0xc3eACf0612346366Db554C991D7858716db09f58 |
| Plasma                    | 0x9eCaf80c1303CCA8791aFBc0AD405c8a35e8d9f1 |

## Bridged KERNEL

### LayerZero KERNEL_OFT

| Network                    | Address                                    |
| -------------------------- | ------------------------------------------ |
| Ethereum KERNEL_OFTAdapter | 0x2A1D74de3027ccE18d31011518C571130a4cd513 |
| BSC                        | 0x9eCaf80c1303CCA8791aFBc0AD405c8a35e8d9f1 |
| Arbitrum                   | 0x6E401189c8A68D05562c9Bab7f674f910821EAcF |

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

### X Layer

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x30CE1444834dbd91e23317179A39d875B16F0DCd |

### Zircuit

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x81E5c1483c6869e95A4f5B00B41181561278179F |

### zkSync

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x6C2e862E7d03e1C9dDa1b30De69b201c7c52e3dB |

### Unichain

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x4Ff0b2CaeFeed2906e96931AD74e265EE2abB61f |

### TAC

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x3222d3De5A9a3aB884751828903044CC4ADC627e |

### Avalanche

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x2A2F37D29143AEa599c57169817A48c04664150b |

### Sonic

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x5c08Bbc2C47447854958060725e437E6Dd003332 |

### Ink

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0x18eC008a42DDF97E86e7AaCCB8308020211e01c9 |

### Plasma

| Contract Name                                                                   | Proxy Address                              |
| ------------------------------------------------------------------------------- | ------------------------------------------ |
| RSETHRateReceiver (Uses RSETHMultiChainRateProvider as provider on ETH mainnet) | 0xF1fD29270e61D4a7885E9B4EF6476Daf2Ab6F85D |
