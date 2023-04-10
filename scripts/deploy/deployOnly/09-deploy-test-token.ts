import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../../utils/helper-functions"
import { networkConfig, developmentChains } from "../../../utils/helper-hardhat-config"
import { ethers } from "hardhat"
import { send } from "process"

const deployToken: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const valve = await ethers.getContract("Valve")
  log("----------------------------------------------------")
  log("Deploying Valve and waiting for confirmations...")
  const token = await deploy("Token", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`Token at ${token.address}`)
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    await verify(token.address, [])
  }
  const tokenContract = await ethers.getContractAt("Token", token.address)
  await tokenContract.mint(valve.address, Number(10**18).toString())
  await tokenContract.balanceOf(valve.address).then(log)
}

export default deployToken
deployToken.tags = ["all", "token"]
