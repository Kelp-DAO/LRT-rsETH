const hre = require('hardhat')

// Array of contract addresses to be verified

const lrtConfig = process.env.LRT_CONFIG ?? ''
const lrtOracle = process.env.LRT_ORACLE ?? ''
const lrtDepositPool = process.env.LRT_DEPOSIT_POOL ?? ''
const rsETH = process.env.RS_ETH ?? ''
const nodeDelegator = process.env.NODE_DELEGATOR ?? ''
const nodeDelegator2 = process.env.NODE_DELEGATOR2 ?? ''
const nodeDelegator3 = process.env.NODE_DELEGATOR3 ?? ''


const contractAddresses = [
    lrtConfig,
    lrtOracle,
    lrtDepositPool,
    rsETH,
    nodeDelegator,
    nodeDelegator2,
    nodeDelegator3
]

async function main() {
  // Loop through all contract addresses and verify them
  for (const contractAddress of contractAddresses) {
    try {
      // Run the hardhat verify task for the current contract address
      await hre.run('verify:verify', {
        address: contractAddress,
      })

      console.log(`Contract at address ${contractAddress} verified successfully!`)
    } catch (error) {
      console.error(`Failed to verify contract at address ${contractAddress}.`)
      console.error(error)
    }
  }
}

// Call the main function to start verifying contracts
main()
