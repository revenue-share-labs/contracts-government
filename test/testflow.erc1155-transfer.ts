import { GovernorContract, GovernanceToken, Valve, GameItems} from "../typechain-types"
import { deployments, ethers } from "hardhat"
import { assert, expect } from "chai"
import {
  VOTING_DELAY,
  VOTING_PERIOD,
  MIN_DELAY,
  NEW_NFT_OWNER, 
  SENDED_AMOUNT, 
  NFT_FUNC,
  NFT_PROPOSAL_DESCRIPTION
} from "../utils/helper-hardhat-config"
import { moveBlocks } from "../utils/move-blocks"
import { moveTime } from "../utils/move-time"

describe("Governor example ERC1155 transfer Flow", async () => {
  let governor: GovernorContract
  let governanceToken: GovernanceToken
  let valve: Valve
  let gameItems: GameItems
  const voteWay = 1 // for
  const reason = "I lika do da cha cha"
  beforeEach(async () => {
    await deployments.fixture(["all"])
    governor = await ethers.getContract("GovernorContract")
    valve = await ethers.getContract("Valve")
    governanceToken = await ethers.getContract("GovernanceToken")
    gameItems = await ethers.getContract("GameItems")
  })

  it("proposes, votes, waits, queues, and then executes NFT transfer", async () => {
    // propose
    const encodedFunctionCall = gameItems.interface.encodeFunctionData(NFT_FUNC, [valve.address, NEW_NFT_OWNER, 0, SENDED_AMOUNT, "0x"])
    const proposeTx = await governor.propose(
      [gameItems.address],
      [0],
      [encodedFunctionCall],
      NFT_PROPOSAL_DESCRIPTION
    )

    const proposeReceipt = await proposeTx.wait(1)
    const proposalId = proposeReceipt.events![0].args!.proposalId
    let proposalState = await governor.state(proposalId)
    console.log(`Current Proposal State: ${proposalState}`)

    await moveBlocks(VOTING_DELAY + 1)
    // vote
    const voteTx = await governor.castVoteWithReason(proposalId, voteWay, reason)
    await voteTx.wait(1)
    proposalState = await governor.state(proposalId)
    assert.equal(proposalState.toString(), "1")
    console.log(`Current Proposal State: ${proposalState}`)
    await moveBlocks(VOTING_PERIOD + 1)

    // queue & execute
    const descriptionHash = ethers.utils.id(NFT_PROPOSAL_DESCRIPTION)
    const queueTx = await governor.queue([gameItems.address], [0], [encodedFunctionCall], descriptionHash)
    await queueTx.wait(1)
    await moveTime(MIN_DELAY + 1)
    await moveBlocks(1)

    proposalState = await governor.state(proposalId)
    console.log(`Current Proposal State: ${proposalState}`)

    console.log("Executing...")
    console.log
    const exTx = await governor.execute([gameItems.address], [0], [encodedFunctionCall], descriptionHash)
    await exTx.wait(1)
    console.log((await gameItems.balanceOf(NEW_NFT_OWNER, 0)).toString())
  })
})
