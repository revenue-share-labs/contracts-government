import { HardhatRuntimeEnvironment} from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../utils/helper-functions"
import { networkConfig, developmentChains} from "../../utils/helper-hardhat-config"
import { ethers } from "hardhat"

const deployGovernanceTokenMulti: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  log("----------------------------------------------------")
  log("Deploying GovernanceToken and waiting for confirmations...")
  const governanceToken = await deploy("GovernanceTokenMulti", {
    from: deployer,
    args: [],
    log: true,
    // we need to wait if on a live network so we can verify properly
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  })
  log(`GovernanceTokenMulti at ${governanceToken.address}`)
  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    await verify(governanceToken.address, [])
  }
  log(`Delegating to ${deployer}`)
  const [owner] =await ethers.getSigners()

  await delegate(owner, governanceToken.address)
  log("Delegated!")
}

const delegate = async (signer: any, governanceTokenAddress: string) => {
  const governanceToken = await ethers.getContractAt("GovernanceTokenMulti", governanceTokenAddress)
  const transactionResponse = await governanceToken.connect(signer).delegate(0, signer.address)
  await transactionResponse.wait(1)
  console.log(`Checkpoints: ${await governanceToken.numCheckpoints(signer.address, 0)}`)
}

export default deployGovernanceTokenMulti
deployGovernanceTokenMulti.tags = ["allMulti", "governorMulti"]
