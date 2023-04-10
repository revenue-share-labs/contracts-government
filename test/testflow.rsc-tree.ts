import { Token, MyBook} from "../typechain-types"
import { deployments, ethers } from "hardhat"
import { assert, expect } from "chai"

describe("RSC tree deploy and Distribute", async () => {
  let token: Token
  let myBook: MyBook
  beforeEach(async () => {
    await deployments.fixture(["all"])
    token = await ethers.getContract("Token")
    myBook = await ethers.getContract("MyBook")
  })

  it("Deploy tree revenue share system", async () => {

    const Valve = await ethers.getContractFactory("Valve");
    var valves = []
    
    const len = 10
    for (var i = 0; i < len; i++){
        let valve = await Valve.deploy(myBook.address, i);
        valves.push(valve)
    }
    
    await token.mint(valves[0].address, Number(10**18).toString())

    for (var i = 0; i < len; i++){
        let balance = await token.balanceOf(valves[i].address)
        console.log(`${valves[i].address}:\t ${balance.toString()}`)
    }

    for (var i = 0; i < len-1; i++){
        myBook.mint(valves[i+1].address, i, 10**6, "0x")
    }

    await valves[0].Split(token.address)
    
    for (var i = 0; i < len-1; i++){
        let data = await myBook.returnPercents(i)
        console.log(data)
    }

console.log("------------------")

    for (var i = 0; i < len; i++){
        let balance = await token.balanceOf(valves[i].address)
        console.log(`${valves[i].address}:\t ${balance.toString()}`)
    }
  })
})
