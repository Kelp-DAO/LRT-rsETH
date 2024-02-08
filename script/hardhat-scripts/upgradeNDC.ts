import { ethers, upgrades } from 'hardhat'

async function main() {
  const NDC = process.env.NODE_DELEGATOR ?? ''
  const ndcFactory = await ethers.getContractFactory('NodeDelegator')
  const ndcInstance = await ndcFactory.attach(NDC)

  const ndcUpgraded = await upgrades.upgradeProxy(ndcInstance, ndcFactory)

  console.log('ndc proxy address ', ndcUpgraded.address)

  console.log('upgraded ndc contract')
}

main()
