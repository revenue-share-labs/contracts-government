import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../../utils/helper-functions"
import { networkConfig, developmentChains } from "../../../utils/helper-hardhat-config"
import { ethers } from "hardhat"

const deployValve: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const myBook = await ethers.getContract("MyBook")
  let index = await myBook.current()
  log("----------------------------------------------------")
  log("Deploying Valve and waiting for confirmations...")
  const valve = await deploy("Valve", {
    from: deployer,
    args: [myBook.address, index],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`Valve at ${valve.address}`)
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    await verify(valve.address, [])
  }
}

export default deployValve
deployValve.tags = ["all", "valve"]
