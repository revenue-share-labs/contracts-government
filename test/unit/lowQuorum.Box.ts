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

describe("Governor example quorum Box Flow", async () => {
  let governor: GovernorContractMulti
  let governanceToken: GovernanceTokenMulti
  let valve: ValveMulti
  let box: Box
  const voteWay = 1 // for
  const reason = "I lika do da cha cha"

  beforeEach(async () => {
    await deployments.fixture(["allMulti"])
    governor = await ethers.getContract("GovernorContractMulti")
    valve = await ethers.getContract("ValveMulti")
    governanceToken = await ethers.getContract("GovernanceTokenMulti")
    box = await ethers.getContract("Box")
  })

  it("can only be changed through governance", async () => {
    await expect(box.store(55)).to.be.revertedWith("Ownable: caller is not the owner")
  })

  it("proposes, votes, waits, queues, and then can't executes because low quorum", async () => {
    // propose
    const [owner, anotherAddress] = await ethers.getSigners();
    let balanceBefore = await governanceToken.balanceOf(owner.address, 0)
    console.log(balanceBefore.toString())
    const transferFromTx = await governanceToken.safeTransferFrom(owner.address, anotherAddress.address, 0, balanceBefore.toString(), "0x")
    await transferFromTx.wait(1)
    // console.log("\n\nTransferFrom:\n\n", res)
    let balanceAfter = await governanceToken.balanceOf(owner.address, 0)
    console.log(balanceAfter.toString())
    let balanceAnother = await governanceToken.balanceOf(anotherAddress.address, 0)
    console.log(balanceAnother.toString())


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
    console.log(proposalId)
    
    let proposalState = await governor.state(0, proposalId)
    console.log(`Current Proposal State: ${proposalState}`)

    await moveBlocks(VOTING_DELAY + 1)
    // vote
    const voteTx = await governor.castVoteWithReason(0, proposalId, voteWay, reason)
    await voteTx.wait(1)
    proposalState = await governor.state(0, proposalId)
    assert.equal(proposalState.toString(), "1")
    console.log(`Current Proposal State: ${proposalState}`)
    await moveBlocks(VOTING_PERIOD + 1)

// Check valve multi
    let valveAddress = await valve.getValve(0)
    console.log(valveAddress)

    // queue revert. Reason low quorum
    const descriptionHash = ethers.utils.id(PROPOSAL_DESCRIPTION)
    console.log("descriptionHash: ", descriptionHash)
    await expect(governor.queue(0, [box.address], [0], [encodedFunctionCall], descriptionHash)).to.be.revertedWith("Governor: proposal not successful")

    await expect(governor.connect(anotherAddress).castVoteWithReason(0, proposalId, voteWay, reason)).to.be.revertedWith("Governor: vote not currently active")

    console.log((await box.retrieve()).toString())
  })

  it("Two voters: proposes, votes, waits, queues, and execute", async () => {
    // propose
    const [owner, anotherAddress, thirdAddress] = await ethers.getSigners();

    console.log(`Checkpoints: ${await governanceToken.numCheckpoints(anotherAddress.address, 0)}`)

    const transactionResponse = await governanceToken.connect(anotherAddress).delegate(0, anotherAddress.address)
    await transactionResponse.wait(1)
    const transactionResponse2 = await governanceToken.connect(thirdAddress).delegate(0, thirdAddress.address)
    await transactionResponse2.wait(1)

    var blockNumber = await ethers.provider.getBlock("latest")
    
    console.log("BLOCKNUMBER ", blockNumber.number)
    var voteOwnerAfter = await governor.getVotes(owner.address, 0, blockNumber.number-1)
    console.log("VOTE OWNER: ", voteOwnerAfter.toString())
    await moveBlocks(1)

    const transferFromTx = await governanceToken.safeTransferFrom(owner.address, anotherAddress.address, 0, 470000, "0x")
    await transferFromTx.wait(1)

    const transferFromTx2 = await governanceToken.connect(anotherAddress).safeTransferFrom(anotherAddress.address, thirdAddress.address, 0, 170000, "0x")
    await transferFromTx2.wait(1)

    const transferFromTx3 = await governanceToken.connect(anotherAddress).safeTransferFrom(anotherAddress.address, owner.address, 0, 100000, "0x")
    await transferFromTx3.wait(1)

    let balanceAfter = await governanceToken.balanceOf(owner.address, 0)
    console.log(balanceAfter.toString())
    let balanceAnother = await governanceToken.balanceOf(anotherAddress.address, 0)
    console.log(balanceAnother.toString())
    await moveBlocks(10)

    console.log(`Checkpoints: ${await governanceToken.numCheckpoints(thirdAddress.address, 0)}`)

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
    );
    const proposeReceipt = await proposeTx.wait(1)
    const proposalId = proposeReceipt.events![0].args!.proposalId
    console.log(proposalId)
    let proposalState = await governor.state(0, proposalId)
    console.log(`Current Proposal State: ${proposalState}`)
    
    await moveBlocks(VOTING_DELAY + 1)

    blockNumber = await ethers.provider.getBlock("latest")    
    console.log("BLOCKNUMBER ", blockNumber.number)
    var voteOwnerAfter = await governor.getVotes(owner.address, 0, blockNumber.number-1)
    console.log("VOTE OWNER: ", voteOwnerAfter.toString())
    const voteTx = await governor.castVoteWithReason(0, proposalId, voteWay, reason)
    await voteTx.wait(1)
    blockNumber = await ethers.provider.getBlock("latest")
    console.log("BLOCKNUMBER ", blockNumber.number)
    var voteOwnerAfter = await governor.getVotes(owner.address, 0, blockNumber.number-1)
    console.log("VOTE OWNER: ", voteOwnerAfter.toString())
    await moveBlocks(1)

    blockNumber = await ethers.provider.getBlock("latest")
    console.log("BLOCKNUMBER ", blockNumber.number)
    var voteOwnerAfter = await governor.getVotes(anotherAddress.address, 0, blockNumber.number-1)
    console.log("VOTE ANOTHER: ", voteOwnerAfter.toString())

    var voteOwnerAfter = await governor.getVotes(thirdAddress.address, 0, blockNumber.number-1)
    console.log("VOTE THIRD: ", voteOwnerAfter.toString())

    const voteTxAnother = await governor.connect(anotherAddress).castVoteWithReason(0, proposalId, voteWay, reason)
    await voteTxAnother.wait(1)

    proposalState = await governor.state(0, proposalId)
    console.log(`Current Proposal State: ${proposalState}`)
    await moveBlocks(VOTING_PERIOD + 1)

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