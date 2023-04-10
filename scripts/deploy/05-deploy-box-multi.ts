import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../utils/helper-functions"
import { networkConfig, developmentChains } from "../../utils/helper-hardhat-config"
import { ethers } from "hardhat"

const deployBoxMulti: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  log("----------------------------------------------------")
  log("Deploying Box and waiting for confirmations...")
  const box = await deploy("Box", {
    from: deployer,
    args: [],
    log: true,
    // we need to wait if on a live network so we can verify properly
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`Box at ${box.address}`)
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    await verify(box.address, [])
  }
  const boxContract = await ethers.getContractAt("Box", box.address)
  const valve = await ethers.getContract("Valve")
  const transferTx = await boxContract.transferOwnership(valve.address)
  await transferTx.wait(1)
}

export default deployBoxMulti
deployBoxMulti.tags = ["allMulti", "boxMulti"]
