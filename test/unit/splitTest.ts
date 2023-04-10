import { GovernanceTokenMulti, Valve, Token} from "./../../typechain-types"
import { deployments, ethers } from "hardhat"
import { assert } from "chai"
describe("Token example Split Flow", async () => {
  let governanceToken: GovernanceTokenMulti
  let token: Token
  let valve: Valve

  beforeEach(async () => {
    await deployments.fixture(["allMulti"])
    governanceToken = await ethers.getContract("GovernanceTokenMulti")
    valve = await ethers.getContract("Valve")
    token = await ethers.getContract("Token")

})

  it("mint, transfer, split", async () => {
    // propose
    const [owner, second, third] = await ethers.getSigners()
    await token.mint(valve.address, 1e6)
    await governanceToken.safeTransferFrom(owner.address, second.address, 0,1e5*3, "0x")
    await governanceToken.safeTransferFrom(owner.address, third.address, 0,1e5*3, "0x")
    await valve.split(token.address)

    let balance1 = await token.balanceOf(owner.address)
    let balance2 = await token.balanceOf(second.address)
    let balance3 = await token.balanceOf(third.address)
    assert(balance1.toString() == "1400000")
    assert(balance2.toString() == "300000")
    assert(balance3.toString() == "300000")
})
})