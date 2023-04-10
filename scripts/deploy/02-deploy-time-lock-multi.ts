import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../utils/helper-functions"
import { networkConfig, developmentChains, MIN_DELAY } from "../../utils/helper-hardhat-config"

const deployValveMulti: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  log("----------------------------------------------------")
  log("Deploying Valve and waiting for confirmations...")
  const valveMulti = await deploy("ValveMulti", {
    from: deployer,
    args: [MIN_DELAY, [], []],
    log: true,
    // we need to wait if on a live network so we can verify properly
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`ValveMulti at ${valveMulti.address}`)
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    await verify(valveMulti.address, [])
  }
}

export default deployValveMulti
deployValveMulti.tags = ["allMulti", "valveMulti"]
