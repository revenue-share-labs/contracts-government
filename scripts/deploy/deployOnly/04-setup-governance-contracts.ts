import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../../utils/helper-functions"
import { networkConfig, developmentChains, ADDRESS_ZERO } from "../../../utils/helper-hardhat-config"
import { ethers } from "hardhat"

const setupContracts: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { log } = deployments
  const { deployer } = await getNamedAccounts()
  const governanceToken = await ethers.getContract("GovernanceToken", deployer)
  const valve = await ethers.getContract("Valve", deployer)
  const governor = await ethers.getContract("GovernorContract", deployer)

  log("----------------------------------------------------")
  log("Setting up contracts for roles...")
  // would be great to use multicall here...
  const proposerRole = await valve.PROPOSER_ROLE()
  const executorRole = await valve.EXECUTOR_ROLE()
  const adminRole = await valve.VAlVE_ADMIN_ROLE()

  const proposerTx = await valve.grantRole(proposerRole, governor.address)
  await proposerTx.wait(1)
  const executorTx = await valve.grantRole(executorRole, ADDRESS_ZERO)
  await executorTx.wait(1)
  const revokeTx = await valve.revokeRole(adminRole, deployer)
  await revokeTx.wait(1)
  // Guess what? Now, anything the timelock wants to do has to go through the governance process!
}

export default setupContracts
setupContracts.tags = ["all", "setup"]
