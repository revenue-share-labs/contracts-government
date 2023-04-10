import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../../utils/helper-functions"
import { networkConfig, developmentChains } from "../../utils/helper-hardhat-config"
import { send } from "process"
import { MyBook, Valve} from "../../typechain-types"
const hre = require("hardhat") 

var config = require('../static/addresses.json');

async function deployBook(): Promise<MyBook>{
    const {network,deployer } = hre
        
    let myBook : MyBook
        let MyBook = await hre.ethers.getContractFactory("MyBook")
        myBook = await MyBook.deploy();
        await myBook.deployed();
        console.log(myBook.address)
        if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
            await verify(myBook.address, [])
          }
        return myBook
}

async function deployValve(address:string, id: string): Promise<Valve>{
    {
        const {network,deployer } = hre
        let valve : Valve
        let Valve = await hre.ethers.getContractFactory("Valve")
        valve = await Valve.deploy();
        await valve.deployed();
        if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
            await verify(valve.address, [address, id])
          }
        return valve
    }
}

async function main(){
    
    console.log("main")
    let myBook = await deployBook()
    let valve = await deployValve(myBook.address, "1")
    console.log(myBook.address)
    console.log(valve.address)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });