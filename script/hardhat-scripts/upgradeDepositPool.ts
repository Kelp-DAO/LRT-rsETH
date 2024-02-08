import { ethers, upgrades } from 'hardhat'

async function main() {
  const lrtDepositPool = process.env.LRT_DEPOSIT_POOL ?? ''
  const lrtDepositPoolFactory = await ethers.getContractFactory('LRTDepositPool')
  const lrtDepositPoolInstance = await lrtDepositPoolFactory.attach(lrtDepositPool)

  const lrtDepositPoolUpgraded = await upgrades.upgradeProxy(lrtDepositPoolInstance, lrtDepositPoolFactory)

  console.log('lrt deposit pool proxy address ', lrtDepositPoolUpgraded.address)

  console.log('upgraded lrt deposit pool contract')
}

main()
