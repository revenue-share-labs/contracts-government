import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../../utils/helper-functions"
import { networkConfig, developmentChains } from "../../../utils/helper-hardhat-config"
import { ethers } from "hardhat"

const deployMyBook: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const valve = await ethers.getContract("Valve")
  log("----------------------------------------------------")
  log("Deploying MyBook and waiting for confirmations...")
  const myBook = await deploy("MyBook", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`myBook at ${myBook.address}`)
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    await verify(myBook.address, [])
  }
  const myBookContract = await ethers.getContractAt("MyBook", myBook.address)
  await myBookContract.balanceOf(valve.address, 0).then(log)
}

export default deployMyBook
deployMyBook.tags = ["all", "myBook"]
