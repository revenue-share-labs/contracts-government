import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../utils/helper-functions"
import { networkConfig, developmentChains, ADDRESS_ZERO } from "../../utils/helper-hardhat-config"
import { ethers } from "hardhat"

const setupContractsMulti: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { log } = deployments
  const { deployer } = await getNamedAccounts()
  // const governanceToken = await ethers.getContract("GovernanceTokenMulti", deployer)
  const valve = await ethers.getContract("Valve", deployer)
  const valveMulti = await ethers.getContract("ValveMulti", deployer)
  const governor = await ethers.getContract("GovernorContractMulti", deployer)

  log("----------------------------------------------------")
  log("Setting up contracts for roles...")
  // would be great to use multicall here...
  const proposerRole = await valve.PROPOSER_ROLE()
  const executorRole = await valve.EXECUTOR_ROLE()
  const adminRole = await valve.VALVE_ADMIN_ROLE()

  const proposerTx = await valve.grantRole(proposerRole, valveMulti.address)
  await proposerTx.wait(1)
  const proposerTx2 = await valve.grantRole(proposerRole, governor.address)
  await proposerTx2.wait(1)
  const executorTx = await valve.grantRole(executorRole, ADDRESS_ZERO)
  await executorTx.wait(1)
  const revokeTx = await valve.revokeRole(adminRole, deployer)
  await revokeTx.wait(1)

  console.log("Valve granted")

  const proposerRoleMulti = await valveMulti.PROPOSER_ROLE()
  const executorRoleMulti = await valveMulti.EXECUTOR_ROLE()
  const adminRoleMulti = await valveMulti.VALVE_ADMIN_ROLE()

  const proposerTxMulti = await valveMulti.grantRole(proposerRoleMulti, governor.address)
  await proposerTxMulti.wait(1)
  const executorTxMulti = await valveMulti.grantRole(executorRoleMulti, ADDRESS_ZERO)
  await executorTxMulti.wait(1)
  const revokeTxMulti = await valveMulti.revokeRole(adminRoleMulti, deployer)
  await revokeTxMulti.wait(1)

  console.log("ValveMulti granted")

  const setValveTx = await valveMulti.setValve(0, valve.address)
  await setValveTx.wait(1)

  console.log("check")

  // Guess what? Now, anything the valve wants to do has to go through the governance process!
}

export default setupContractsMulti
setupContractsMulti.tags = ["allMulti", "setupMulti"]
