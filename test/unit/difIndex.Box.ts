import { GovernorContractMulti, GovernanceTokenMulti, ValveMulti, Box, Valve} from "../../typechain-types"
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

describe("Different index", async () => {
  let governor: GovernorContractMulti
  let governanceToken: GovernanceTokenMulti
  let valveMulti: ValveMulti
  let valve: Valve
  let box: Box
  const voteWay = 1 // for
  const reason = "I lika do da cha cha"
  beforeEach(async () => {
    await deployments.fixture(["allMulti"])
    governor = await ethers.getContract("GovernorContractMulti")
    valveMulti = await ethers.getContract("ValveMulti")
    governanceToken = await ethers.getContract("GovernanceTokenMulti")
    box = await ethers.getContract("Box")
    valve = await ethers.getContract("Valve")
  })

it("Different Index", async () => {

    const setValveTx = await valveMulti.setValve(1, valve.address)
    await setValveTx.wait(1)
  
    const [owner, anotherAddress, thirdAddress] = await ethers.getSigners();

    await governanceToken.connect(owner).mint(owner.address, 1, 1000000, "0x")
    console.log("Minted")


    var blockNumber = await ethers.provider.getBlock("latest")
    var voteOwnerAfter

    const transferFromTx = await governanceToken.safeTransferFrom(owner.address, anotherAddress.address, 1, 470000, "0x")
    await transferFromTx.wait(1)

    const transferFromTx2 = await governanceToken.connect(anotherAddress).safeTransferFrom(anotherAddress.address, thirdAddress.address, 1, 170000, "0x")
    await transferFromTx2.wait(1)

    const transferFromTx3 = await governanceToken.connect(anotherAddress).safeTransferFrom(anotherAddress.address, owner.address, 1, 100000, "0x")
    await transferFromTx3.wait(1)

    var blockNumber = await ethers.provider.getBlock("latest")

    voteOwnerAfter = await governor.getVotes(thirdAddress.address, 1, blockNumber.number-1)
    console.log("VOTE THIRD: ", voteOwnerAfter.toString() == "0")
    let balanceOf = await governanceToken.balanceOf(thirdAddress.address, 1)
    assert(voteOwnerAfter.toString() == "0", "Should be equal zero")


    const transactionResponse0 = await governanceToken.connect(owner).delegate(1, owner.address)
    await transactionResponse0.wait(1)
    const transactionResponse2 = await governanceToken.connect(thirdAddress).delegate(1, thirdAddress.address)
    await transactionResponse2.wait(1)
    const transactionResponse = await governanceToken.connect(anotherAddress).delegate(1, anotherAddress.address)
    await transactionResponse.wait(1)

    var blockNumber = await ethers.provider.getBlock("latest")

    voteOwnerAfter = await governor.getVotes(thirdAddress.address, 1, blockNumber.number-1)
    assert(voteOwnerAfter.toString() == balanceOf.toString(), "Should be equal ")




    // propose
    const encodedFunctionCall = box.interface.encodeFunctionData(FUNC, [NEW_STORE_VALUE])
    const proposeTx = await governor["propose(uint256,address[],uint256[],bytes[],string,uint256,uint256)"](
      1,
      [box.address],
      [0],
      [encodedFunctionCall],
      PROPOSAL_DESCRIPTION,
      45818,
      1
    )
    const proposeReceipt = await proposeTx.wait(1)
    const proposalId = proposeReceipt.events![0].args!.proposalId
    // console.log(proposalId)
    let proposalState = await governor.state(1, proposalId)
    console.log(`Current Proposal State: ${proposalState}`)
    

    await moveBlocks(VOTING_DELAY + 1)


    blockNumber = await ethers.provider.getBlock("latest")    
    console.log("BLOCKNUMBER ", blockNumber.number)
    voteOwnerAfter = await governor.getVotes(owner.address, 1, blockNumber.number-1)
    console.log("VOTE OWNER: ", voteOwnerAfter.toString())
    voteOwnerAfter = await governor.getVotes(anotherAddress.address, 1, blockNumber.number-1)
    console.log("VOTE ANOTHER: ", voteOwnerAfter.toString())
    voteOwnerAfter = await governor.getVotes(thirdAddress.address, 1, blockNumber.number-1)
    console.log("VOTE THIRD: ", voteOwnerAfter.toString())

    const voteTx = await governor.castVoteWithReason(1, proposalId, voteWay, reason)
    await voteTx.wait(1)

    const voteTxAnother = await governor.connect(anotherAddress).castVoteWithReason(1, proposalId, voteWay, reason)
    await voteTxAnother.wait(1)

    const voteTx3 = await governor.connect(thirdAddress).castVoteWithReason(1, proposalId, 0, reason)
    await voteTx3.wait(1)

    proposalState = await governor.state(1, proposalId)
    console.log(`Current Proposal State: ${proposalState}`)
    await moveBlocks(VOTING_PERIOD + 1)

    let proposalState2 = await governor.state(1, proposalId)
    console.log(`Current Proposal State: ${proposalState2}`)

    // queue & execute
    const descriptionHash = ethers.utils.id(PROPOSAL_DESCRIPTION)
    console.log("descriptionHash: ", descriptionHash)
    let queueTx = await governor.queue(1, [box.address], [0], [encodedFunctionCall], descriptionHash)
    await queueTx.wait(1)
    await moveTime(MIN_DELAY + 1)
    await moveBlocks(1)

    proposalState = await governor.state(1, proposalId)
    console.log(`Current Proposal State: ${proposalState}`)

    console.log("Executing...")
    console.log
    const exTx = await governor.execute(1, [box.address], [0], [encodedFunctionCall], descriptionHash)
    await exTx.wait(1)
    console.log((await box.retrieve()).toString())

    proposalState2 = await governor.state(1, proposalId)
    console.log(`Current Proposal State: ${proposalState2}`)

  })
})