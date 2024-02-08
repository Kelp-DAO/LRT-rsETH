import { ethers } from "hardhat";

async function main() {
  const lrtDepositPool = process.env.LRT_DEPOSIT_POOL ?? "";
  const lrtDepositPoolFactory = await ethers.getContractFactory("LRTDepositPool");
  const lrtDepositPoolInstance = await lrtDepositPoolFactory.attach(lrtDepositPool);

  const assetAddress = process.env.ASSET_ADDRESS ?? "";
  const depositAmount = ethers.utils.parseEther("0.005");
  const minimumAmountOfRSETHForDeposit = lrtDepositPool.getRsETHAmountToMint(assetAddress, depositAmount);
  const referralId = 0;
  const depositTx = await lrtDepositPoolInstance.depositAsset(
    assetAddress,
    depositAmount,
    minimumAmountOfRSETHForDeposit,
    referralId,
  );
  depositTx.wait();
  console.log(`deposited ${depositAmount} successfully`);
}

main();
