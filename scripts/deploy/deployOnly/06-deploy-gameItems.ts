import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../../utils/helper-functions"
import { networkConfig, developmentChains } from "../../../utils/helper-hardhat-config"
import { ethers } from "hardhat"

const deployGameItems: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const valve = await ethers.getContract("Valve")
  log("----------------------------------------------------")
  log("Deploying gameItems and waiting for confirmations...")
  const gameItems = await deploy("GameItems", {
    from: deployer,
    args: [valve.address],
    log: true,
    // we need to wait if on a live network so we can verify properly
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`gameItems at ${gameItems.address}`)
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    await verify(gameItems.address, [])
  }
  const gameItemsContract = await ethers.getContractAt("GameItems", gameItems.address)
  await gameItemsContract.balanceOf(valve.address, 0).then(log)
}

export default deployGameItems
deployGameItems.tags = ["all", "gameItems"]
