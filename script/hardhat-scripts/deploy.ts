import { ethers, upgrades } from 'hardhat'

async function main() {

  console.log('starting deployment process...')
  const [deployer] = await ethers.getSigners()
  const rETH = process.env.R_ETH ?? ''
  const stETH = process.env.ST_ETH ?? ''
  const cbETH = process.env.CB_ETH ?? ''

  const lrtConfigFactory = await ethers.getContractFactory('LRTConfig')
  const lrtConfig = await upgrades.deployProxy(lrtConfigFactory, [deployer.address,
      stETH,
      rETH,
      cbETH,
      cbETH])
  console.log('LRT config deployed at ', lrtConfig.target)

  const rsETHFactory = await ethers.getContractFactory('RSETH')
  const rsETHToken = await upgrades.deployProxy(rsETHFactory, [deployer.address,lrtConfig.target])
  console.log('rsETH Token deployed at ', rsETHToken.target)

  const lrtDepositPoolFactory = await ethers.getContractFactory('LRTDepositPool')
  const lrtDepositPool = await upgrades.deployProxy(lrtDepositPoolFactory, [lrtConfig.target])
  console.log('lrtDepositPool deployed at ', lrtDepositPool.target)

  const lrtOracleFactory = await ethers.getContractFactory('LRTOracle')
  const lrtOracle = await upgrades.deployProxy(lrtOracleFactory, [lrtConfig.target])
  console.log('lrtOracle deployed at ', lrtOracle.target)

  const chainlinkOracleFactory = await ethers.getContractFactory('ChainlinkPriceOracle')
  const chailinkOracle = await upgrades.deployProxy(chainlinkOracleFactory, [lrtConfig.target])
  console.log('chailinkOracle deployed at ', await chailinkOracle.getAddress())

  const nodeDelegatorFactory = await ethers.getContractFactory('NodeDelegator')
  const nodeDelegator1 = await upgrades.deployProxy(nodeDelegatorFactory, [lrtConfig.target])
  console.log('nodeDelegator1 deployed at ', nodeDelegator1.target)
  const nodeDelegator2 = await upgrades.deployProxy(nodeDelegatorFactory, [lrtConfig.target])
  console.log('nodeDelegator2 deployed at ', nodeDelegator2.target)
  const nodeDelegator3 = await upgrades.deployProxy(nodeDelegatorFactory, [lrtConfig.target])
  console.log('nodeDelegator3 deployed at ', nodeDelegator3.target)
  const nodeDelegator4 = await upgrades.deployProxy(nodeDelegatorFactory, [lrtConfig.target])
  console.log('nodeDelegator4 deployed at ', nodeDelegator4.target)
  const nodeDelegator5 = await upgrades.deployProxy(nodeDelegatorFactory, [lrtConfig.target])
  console.log('nodeDelegator5 deployed at ', nodeDelegator5.target)

}

main()
