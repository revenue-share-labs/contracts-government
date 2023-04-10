import { GovernorContractMulti, GovernanceTokenMulti, ValveMulti, Box} from "../../typechain-types"
import { deployments, ethers } from "hardhat"
import { assert, expect } from "chai"
import {
  FUNC,
  PROPOSAL_DESCRIPTION,
  NEW_STORE_VALUE,
  VOTING_DELAY,
  VOTING_PERIOD,
  MIN_DELAY,
} from "../../utils/helper-hardhat-config"
import { moveBlocks } from "../../utils/move-blocks"
import { moveTime } from "../../utils/move-time"

describe("Governor example Box Flow", async () => {
  let governor: GovernorContractMulti
  let governanceToken: GovernanceTokenMulti
  let valveMulti: ValveMulti
  let box: Box
  const voteWay = 1 // for
  const reason = "I lika do da cha cha"
  beforeEach(async () => {
    await deployments.fixture(["allMulti"])
    governor = await ethers.getContract("GovernorContractMulti")
    valveMulti = await ethers.getContract("ValveMulti")
    governanceToken = await ethers.getContract("GovernanceTokenMulti")
    box = await ethers.getContract("Box")
  })
  it("can only be changed through governance", async () => {
    await expect(box.store(55)).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("proposes, votes, waits, queues, and then executes", async () => {
    // propose
    const encodedFunctionCall = box.interface.encodeFunctionData(FUNC, [NEW_STORE_VALUE])
    const proposeTx = await governor["propose(uint256,address[],uint256[],bytes[],string,uint256,uint256)"](
      0,
      [box.address],
      [0],
      [encodedFunctionCall],
      PROPOSAL_DESCRIPTION,
      45818,
      1
    )
    const proposeReceipt = await proposeTx.wait(1)
    const proposalId = proposeReceipt.events![0].args!.proposalId
    let proposalState = await governor.state(0, proposalId)
    console.log(`Current Proposal State: ${proposalState}`)

    await moveBlocks(VOTING_DELAY + 1)
    // vote
    const voteTx = await governor.castVoteWithReason(0, proposalId, voteWay, reason)
    await voteTx.wait(1)
    const [owner] = await ethers.getSigners()
    const blockNumber = await ethers.provider.getBlock("latest")
    console.log("BLOCKNUMBER ", blockNumber.number)
    const voteOwnerAfter = await governor.getVotes(owner.address, 0, blockNumber.number-1)
    console.log("VOTE: ", voteOwnerAfter.toString())


    proposalState = await governor.state(0, proposalId)
    assert.equal(proposalState.toString(), "1")
    console.log(`Current Proposal State: ${proposalState}`)
    await moveBlocks(VOTING_PERIOD + 1)

// Check valve multi
    let valveAddress = await valveMulti.getValve(0)
    console.log(valveAddress)

    // queue & execute
    const descriptionHash = ethers.utils.id(PROPOSAL_DESCRIPTION)
    console.log("descriptionHash: ", descriptionHash)
    let queueTx = await governor.queue(0, [box.address], [0], [encodedFunctionCall], descriptionHash)
    // console.log(queueTx)
    await queueTx.wait(1)
    await moveTime(MIN_DELAY + 1)
    await moveBlocks(1)

    proposalState = await governor.state(0, proposalId)
    console.log(`Current Proposal State: ${proposalState}`)

    console.log("Executing...")
    console.log
    const exTx = await governor.execute(0, [box.address], [0], [encodedFunctionCall], descriptionHash)
    await exTx.wait(1)
    console.log((await box.retrieve()).toString())
  })
})