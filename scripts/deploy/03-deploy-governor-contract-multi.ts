import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../utils/helper-functions"
import {
  networkConfig,
  developmentChains,
  QUORUM_PERCENTAGE,
  VOTING_PERIOD,
  VOTING_DELAY,
} from "../../utils/helper-hardhat-config"

const deployGovernorContractMulti: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log, get } = deployments
  const { deployer } = await getNamedAccounts()
  const governanceToken = await get("GovernanceTokenMulti")
  const valveMulti = await get("ValveMulti")
  const args = [
      governanceToken.address,
      valveMulti.address,
      QUORUM_PERCENTAGE,
      VOTING_PERIOD,
      VOTING_DELAY,
  ]
  
  log("----------------------------------------------------")
  log("Deploying GovernorContract and waiting for confirmations...")
  const governorContract = await deploy("GovernorContractMulti", {
    from: deployer,
    args, 
    log: true,
    // we need to wait if on a live network so we can verify properly
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`GovernorContractMulti at ${governorContract.address}`)
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    await verify(governorContract.address, args)
  }
}

export default deployGovernorContractMulti
deployGovernorContractMulti.tags = ["allMulti", "governorMulti"]
