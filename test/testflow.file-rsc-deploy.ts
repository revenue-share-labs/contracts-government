import { Token, MyBook} from "../typechain-types"
import { deployments, ethers } from "hardhat"
import { assert, expect } from "chai"
import fs from "fs"
import { TSMap } from "typescript-map"
var config = require('../../static/config.json');

describe("RSC tree file deploy and Distribute", async () => {
  it("Deploy tree revenue share system", async () => {
    const Token = await ethers.getContractFactory("Token")
    let token = await Token.deploy()
    const MyBook = await ethers.getContractFactory("MyBook")
    let myBook = await MyBook.deploy()

    console.log(config)

    const Valve = await ethers.getContractFactory("Valve");

    var valves = []


    const len = config["node_amount"]
    for (var i = 0; i < len; i++){
        let valve = await Valve.deploy();
        valves.push(valve)
    }

    await token.mint(valves[0].address, Number(10**18).toString())

    let valve_json = new TSMap()
    valve_json.set("book", myBook.address) 
    for (var i = 0; i < len; i++){
        let balance = await token.balanceOf(valves[i].address)
        console.log(`${valves[i].address}:\t ${balance.toString()}`)
        const index = `valve-${i}`
        valve_json.set(index, valves[i].address) 
    }

    for (var i = 0; i < len; i++){
        var share = config["shares"][i]
        for (var pie in share) {
            console.log(pie)
            if (ethers.utils.isAddress(pie)){
                myBook.mint(pie, i, share[pie], "0x")
            } else {
                myBook.mint(valves[Number(pie)].address, i, share[pie], "0x")
            }
    }
    }

    await valves[0].split(token.address)

    for (var i = 0; i < len-1; i++){
        let data = await myBook.returnPercents(i)
        console.log(data)
    }

    console.log("------------------")

    for (var i = 0; i < len; i++){
        let balance = await token.balanceOf(valves[i].address)
        console.log(`${valves[i].address}:\t ${balance.toString()}`)
    }
    let balance = await token.balanceOf("0x3604226674A32B125444189D21A51377ab0173d1")
    console.log(`${"0x3604226674A32B125444189D21A51377ab0173d1"}:\t ${balance.toString()}`)

    var myJSON = JSON.stringify(valve_json.toJSON())
    fs.writeFile("static/addresses.json", myJSON, 'utf8', function(err) {
        if (err) throw err;
        console.log('complete');
        })
    })
})
