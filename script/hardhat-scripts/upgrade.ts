import * as hardhat from "hardhat";

export class Upgrader {
  private async getArtifacts() {
    return {
      NodeDelegator: await hardhat.ethers.getContractFactory("NodeDelegator"),
      LRTDepositPool: await hardhat.ethers.getContractFactory("LRTDepositPool"),
      LRTOracle: await hardhat.ethers.getContractFactory("LRTOracle"),
      ChainlinkPriceOracle: await hardhat.ethers.getContractFactory("ChainlinkPriceOracle"),
      EthXPriceOracle: await hardhat.ethers.getContractFactory("EthXPriceOracle"),
      LRTConfig: await hardhat.ethers.getContractFactory("LRTConfig"),
      RSETH: await hardhat.ethers.getContractFactory("RSETH"),
    };
  }

  // use to validate upgrade before running it or passing it to Gnosis Safe
  async validateUpgrade(contractName: string, contractAddress: string) {
    const artifacts = await this.getArtifacts();

    const contractArtifact = artifacts[contractName];

    if (contractArtifact === undefined) {
      throw new Error(`Contract ${contractName} not found`);
    }

    await hardhat.upgrades.validateUpgrade(contractAddress, contractArtifact, { kind: "transparent" });
  }

  // used to store impl record for proxies in .openzeppelin folder
  async forceImportDeployedProxies(contractName: string, contractAddress: string) {
    const artifacts = await this.getArtifacts();

    const contractArtifact = artifacts[contractName];

    if (contractArtifact === undefined) {
      throw new Error(`Contract ${contractName} not found`);
    }

    await hardhat.upgrades.forceImport(contractAddress, contractArtifact, { kind: "transparent" });
  }

  async run(contractName: string, contractAddress: string) {
    const artifacts = await this.getArtifacts();

    const contractArtifact = artifacts[contractName];

    if (contractArtifact === undefined) {
      throw new Error(`Contract ${contractName} not found`);
    }

    const contractInstance = await hardhat.upgrades.upgradeProxy(contractAddress, contractArtifact, {});
    await contractInstance.deployTransaction.wait();

    const proxyAdmin = await hardhat.upgrades.admin.getInstance();
    const contractImpl = await proxyAdmin.callStatic.getProxyImplementation(contractInstance.address);
    console.log("Contract implementation ", contractImpl);
  }
}

async function main() {
  console.log("START!");

  const upgrader = new Upgrader();
  // (contractName: string, contractAddress: string)
  // await upgrader.validateUpgrade("", "");
  // await upgrader.run("", "");

  console.log("END!");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
