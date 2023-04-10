import { GovernorContractMulti, GovernanceTokenMulti, ValveMulti, Box, Valve, Token} from "../../typechain-types"
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect, assert } from "chai";
import { deployments, ethers } from "hardhat"
import {
    VOTING_DELAY,
    VOTING_PERIOD,
    MIN_DELAY,
    ADDRESS_ZERO
  } from "../../utils/helper-hardhat-config"
  import { moveBlocks } from "../../utils/move-blocks"
  import { moveTime } from "../../utils/move-time"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signers";
  

describe("Try split funds, Vote and split again", function () {
    const MaxSupply = 1_000_000
    let governor: GovernorContractMulti
    let governanceToken: GovernanceTokenMulti
    let valveMulti: ValveMulti
    let valve: Valve
    let token: Token
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
        token = await ethers.getContract("Token")
      })
  
async function settingValve(valve:any, owner:SignerWithAddress, index: any, supply:any, beneficiary:any){
    const proposerRole = await valve.PROPOSER_ROLE()
    const executorRole = await valve.EXECUTOR_ROLE()
    const adminRole = await valve.VALVE_ADMIN_ROLE()
  
    const proposerTx = await valve.grantRole(proposerRole, valveMulti.address)
    await proposerTx.wait(1)
    const proposerTx2 = await valve.grantRole(proposerRole, governor.address)
    await proposerTx2.wait(1)
    const executorTx = await valve.grantRole(executorRole, ADDRESS_ZERO)
    await executorTx.wait(1)
    const revokeTx = await valve.revokeRole(adminRole, owner.address)
    await revokeTx.wait(1)
    await valveMulti.setValve(index, valve.address)
    await governanceToken.connect(owner).safeTransferFrom(owner.address, valve.address, 0, supply, "0x")
    await governanceToken.mint(beneficiary, index, MaxSupply, "0x")
    
}

async function deployTimes() {
    const [owner, second, third] = await ethers.getSigners()
    const Valve = await ethers.getContractFactory("Valve");
    const valve1 = await Valve.deploy();
    console.log("VALVE1: ",valve1.address)
    await settingValve(valve1, owner, 1, MaxSupply/2, second.address)
    // const Time2 = await ethers.getContractFactory("TimeLock");
    const valve2 = await Valve.deploy();
    console.log("VALVE2: ",valve2.address)
    await settingValve(valve2, owner, 2, MaxSupply/2, third.address)
    await governanceToken.connect(owner).delegate(0, owner.address)
    await governanceToken.connect(owner).delegate(1, owner.address)
    await governanceToken.connect(owner).delegate(2, owner.address)
    await governanceToken.connect(second).delegate(0, second.address)
    await governanceToken.connect(second).delegate(1, second.address)
    await governanceToken.connect(second).delegate(2, second.address)
    await governanceToken.connect(third).delegate(0, third.address)
    await governanceToken.connect(third).delegate(1, third.address)
    await governanceToken.connect(third).delegate(2, third.address)

    
    return {valve1, valve2, owner, second, third};
  }
  it("Check deploy", async function(){
    // await beforeEach()
    const { valve1, valve2, owner, second, third} = await loadFixture(deployTimes);
    expect(await governanceToken.balanceOf(valve1.address, 0)).to.equal(MaxSupply/2)
    expect(await governanceToken.balanceOf(valve2.address, 0)).to.equal(MaxSupply/2)
    expect(await governanceToken.balanceOf(owner.address, 0)).to.equal(0)
    expect(await governanceToken.balanceOf(second.address, 1)).to.equal(MaxSupply)
    expect(await governanceToken.balanceOf(third.address, 2)).to.equal(MaxSupply)
});
    it("Check Split", async function(){
        const { valve1, valve2, owner, second, third} = await deployTimes();
        const mint = await token.mint(valve.address, MaxSupply)
        await mint.wait(1)
        expect(await token.balanceOf(valve.address)).to.equal(MaxSupply)
        await valve.split(token.address, {gasLimit:2000000})
        expect(await token.balanceOf(second.address)).to.equal(MaxSupply/2)
        expect(await token.balanceOf(third.address)).to.equal(MaxSupply/2)
        expect(await token.balanceOf(valve1.address)).to.equal(0)
        expect(await token.balanceOf(valve2.address)).to.equal(0)
        expect(await token.balanceOf(owner.address)).to.equal(MaxSupply)
    })

    it("Single Vote and split", async function(){
        const { valve1, valve2, owner, second, third} = await deployTimes();
        await token.mint(valve.address, MaxSupply)
        expect(await token.balanceOf(valve.address)).to.equal(MaxSupply)
        //  For Vote
        await governanceToken.connect(second).safeTransferFrom(second.address, third.address, 1, 333333, "0x")
        await governanceToken.connect(second).safeTransferFrom(second.address, owner.address, 1, 333333, "0x")
        await governanceToken.connect(third).safeTransferFrom(third.address, second.address, 2, 333333, "0x")
        await governanceToken.connect(third).safeTransferFrom(third.address, owner.address, 2, 333333, "0x")

        expect(await governanceToken.balanceOf(third.address, 1)).to.equal(333333)
        // console.log((await governanceToken.balanceOf(second.address, 1)).toString())
        const percents = await governanceToken.returnPercents(1)
        for (var i in percents){
            console.log("PERCENTS", percents[i][0], percents[i][1].toString())
        }
        expect(await governanceToken.balanceOf(second.address, 1)).to.equal(333334)
        expect(await governanceToken.balanceOf(owner.address, 1)).to.equal(333333)
    

        // GOVERNANCE PLACE
        /////////////////////////////////////////////////////////////////////////////
        const encodedFunctionCall = governanceToken.interface.encodeFunctionData("safeTransferFrom", [valve1.address, owner.address, 0, MaxSupply/2, "0x"])
        const NEW_PROPOSAL_DESCRIPTION = "SEND SUPPLY FOR VALVE #1" 
        const proposeTx = await governor["propose(uint256,address[],uint256[],bytes[],string,uint256,uint256)"](
          1,
          [governanceToken.address],
          [0],
          [encodedFunctionCall],
          NEW_PROPOSAL_DESCRIPTION,
          45818,
          1
        )
        const proposeReceipt = await proposeTx.wait(1)
        const proposalId = proposeReceipt.events![0].args!.proposalId
        let proposalState = await governor.state(1, proposalId)
        console.log(`Current Proposal State: ${proposalState}`)
    
        await moveBlocks(VOTING_DELAY + 1)
        // vote
        await governor.connect(second).castVoteWithReason(1, proposalId, voteWay, reason)
        await governor.connect(owner).castVoteWithReason(1, proposalId, voteWay, reason)
        await governor.connect(third).castVoteWithReason(1, proposalId, voteWay, reason)
        const blockNumber = await ethers.provider.getBlock("latest")
        console.log("BLOCKNUMBER ", blockNumber.number)
        const voteOwnerAfter = await governor.getVotes(owner.address, voteWay, blockNumber.number-1)
        console.log("VOTE: ", voteOwnerAfter.toString())
    
    
        proposalState = await governor.state(1, proposalId)
        assert.equal(proposalState.toString(), "1")
        console.log(`Current Proposal State: ${proposalState}`)
        await moveBlocks(VOTING_PERIOD + 1)
    
        // queue & execute
        const descriptionHash = ethers.utils.id(NEW_PROPOSAL_DESCRIPTION)
        console.log("descriptionHash: ", descriptionHash)
        let queueTx = await governor.queue(1, [governanceToken.address], [0], [encodedFunctionCall], descriptionHash)
        // console.log(queueTx)
        await queueTx.wait(1)
        await moveTime(MIN_DELAY + 1)
        await moveBlocks(1)
    
        proposalState = await governor.state(1, proposalId)
        console.log(`Current Proposal State: ${proposalState}`)
    
        console.log("Executing...")
        const exTx = await governor.execute(1, [governanceToken.address], [0], [encodedFunctionCall], descriptionHash)
        await exTx.wait(1)
    
        const percents2 = await governanceToken.returnPercents(0)
        for (var i in percents2){
            console.log("PERCENTS", percents2[i][0], percents2[i][1].toString())
        }

        await valve.split(token.address, {gasLimit:2000000})
        console.log((await token.balanceOf(owner.address)).toString())    
        // expect(await token.balanceOf(second.address)).to.equal(0)
        console.log((await token.balanceOf(third.address)).toString())
    })

    // it("Multi Vote and split", async function(){
    //     const { time1, time2, owner, second, third} = await deployTimes();
    //     await token.mint(timeLock.address, MaxSupply)
    //     expect(await token.balanceOf(timeLock.address)).to.equal(MaxSupply)
    //     //  For Vote
    //     // await governanceToken.connect(second).safeTransferFrom(second.address, third.address, 1, 333333, "0x")
    //     // await governanceToken.connect(second).safeTransferFrom(second.address, owner.address, 1, 333333, "0x")
    //     // await governanceToken.connect(third).safeTransferFrom(third.address, second.address, 2, 333333, "0x")
    //     // await governanceToken.connect(third).safeTransferFrom(third.address, owner.address, 2, 333333, "0x")

    //     expect(await governanceToken.balanceOf(third.address, 1)).to.equal(333333)
    //     // console.log((await governanceToken.balanceOf(second.address, 1)).toString())
    //     const percents = await governanceToken.returnPercents(1)
    //     for (var i in percents){
    //         console.log("PERCENTS", percents[i][0], percents[i][1].toString())
    //     }
    //     expect(await governanceToken.balanceOf(second.address, 1)).to.equal(333334)
    //     expect(await governanceToken.balanceOf(owner.address, 1)).to.equal(333333)
    

    //     // GOVERNANCE PLACE
    //     /////////////////////////////////////////////////////////////////////////////
    //     const encodedFunctionCall = governanceToken.interface.encodeFunctionData("safeTransferFrom", [time1.address, owner.address, 0, MaxSupply/2, "0x"])
    //     const NEW_PROPOSAL_DESCRIPTION = "SEND SUPPLY FOR VALVE #1" 
    //     const proposeTx = await governor.propose(
    //       1,
    //       [governanceToken.address],
    //       [0],
    //       [encodedFunctionCall],
    //       NEW_PROPOSAL_DESCRIPTION
    //     )
    //     const proposeReceipt = await proposeTx.wait(1)
    //     const proposalId = proposeReceipt.events![0].args!.proposalId
    //     let proposalState = await governor.state(1, proposalId)
    //     console.log(`Current Proposal State: ${proposalState}`)
    
    //     await moveBlocks(VOTING_DELAY + 1)
    //     // vote
    //     await governor.connect(second).castVoteWithReason(1, proposalId, voteWay, reason)
    //     await governor.connect(owner).castVoteWithReason(1, proposalId, voteWay, reason)
    //     await governor.connect(third).castVoteWithReason(1, proposalId, voteWay, reason)
    //     const blockNumber = await ethers.provider.getBlock("latest")
    //     console.log("BLOCKNUMBER ", blockNumber.number)
    //     const voteOwnerAfter = await governor.getVotes(owner.address, voteWay, blockNumber.number-1)
    //     console.log("VOTE: ", voteOwnerAfter.toString())
    
    
    //     proposalState = await governor.state(1, proposalId)
    //     assert.equal(proposalState.toString(), "1")
    //     console.log(`Current Proposal State: ${proposalState}`)
    //     await moveBlocks(VOTING_PERIOD + 1)
    
    //     // queue & execute
    //     const descriptionHash = ethers.utils.id(NEW_PROPOSAL_DESCRIPTION)
    //     console.log("descriptionHash: ", descriptionHash)
    //     let queueTx = await governor.queue(1, [governanceToken.address], [0], [encodedFunctionCall], descriptionHash)
    //     // console.log(queueTx)
    //     await queueTx.wait(1)
    //     await moveTime(MIN_DELAY + 1)
    //     await moveBlocks(1)
    
    //     proposalState = await governor.state(1, proposalId)
    //     console.log(`Current Proposal State: ${proposalState}`)
    
    //     console.log("Executing...")
    //     const exTx = await governor.execute(1, [governanceToken.address], [0], [encodedFunctionCall], descriptionHash)
    //     await exTx.wait(1)
    
    //     const percents2 = await governanceToken.returnPercents(0)
    //     for (var i in percents2){
    //         console.log("PERCENTS", percents2[i][0], percents2[i][1].toString())
    //     }

    //     await timeLock.Split(token.address, {gasLimit:2000000})
    //     console.log((await token.balanceOf(owner.address)).toString())    
    //     // expect(await token.balanceOf(second.address)).to.equal(0)
    //     console.log((await token.balanceOf(third.address)).toString())
    // })
})

// function hashProposal(
//     address[] memory targets,
//     uint256[] memory values,
//     bytes[] memory calldatas,
//     bytes32 descriptionHash
// ) public pure virtual override returns (uint256) {
//     return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
// }
