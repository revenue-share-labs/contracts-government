import { Token, MyBook} from "../typechain-types"
import { deployments, ethers } from "hardhat"
import { assert, expect } from "chai"

describe("Book transfer with reconfigurate percents", async () => {
  it("Deploy tree revenue share system", async () => {
    await deployments.fixture(["all"])
    const token = await ethers.getContractFactory("Token")
    const Token = await token.deploy();
    const myBook = await ethers.getContractFactory("MyBook")
    const MyBook = await myBook.deploy();

    const Valve = await ethers.getContractFactory("Valve");
    let valve = await Valve.deploy();
    let me = await Token.owner()
    
    MyBook.mint(me, 0, 10**6, "0x")

    let data = await MyBook.returnPercents(0)
    console.log(data)

    console.log("------------------")

    await MyBook.safeTransferFrom(me, valve.address,0, 10**6 / 4, "0x00")

    data = await MyBook.returnPercents(0)
    console.log(data)

  })
})
