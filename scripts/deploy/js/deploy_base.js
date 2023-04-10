const { ethers } = require('hardhat');

const verify = async (contractAddress, args) => {
    console.log("Verifying contract...")
    try {
      await run("verify:verify", {
        address: contractAddress,
        constructorArguments: args,
      })
    } catch (e) {
      if (e.message.toLowerCase().includes("already verified")) {
        console.log("Already verified!")
      } else {
        console.log(e)
      }
    }
  }
  

async function main(){
    try { 
        const GTD = await ethers.getContractFactory("GovernanceTokenDeployer");
        const GovernorTokenDeployer = await GTD.deploy();
        await GovernorTokenDeployer.deployed();
        // await verify(GovernorTokenDeployer.address, [])

        const GCMD = await ethers.getContractFactory("GovernorContractMultiDeployer");
        const GovConMulDep = await GCMD.deploy();
        await GovConMulDep.deployed();
        // await verify(GovConMulDep.address, [])


        const TLMD = await ethers.getContractFactory("TimeLockMultiDeployer");
        const TimeLockMultiD = await TLMD.deploy();
        await TimeLockMultiD.deployed();
        // await verify(TimeLockMultiD.address, [])

        const VL = await ethers.getContractFactory("TimeLock");
        const TimeLock = await VL.deploy();
        await TimeLock.deployed();
        // await verify(TimeLock.address, [])

        const contractDeployer = await ethers.getContractFactory("SystemDeployer");
        const SystemDeployer = await contractDeployer.deploy(TimeLock.address);
        await SystemDeployer.deployed();
        // await verify(SystemDeployer.address, [TimeLock.address])

        console.log("Contract deployer", SystemDeployer.address);
        console.log("governor token", GovernorTokenDeployer.address);
        console.log("timelock d", TimeLockMultiD.address);
        console.log("governor", GovConMulDep.address);

        await SystemDeployer.setDeployers(
            GovernorTokenDeployer.address,
            TimeLockMultiD.address,
            GovConMulDep.address
        );            

    } catch(err) {
        console.log(err);
    }
}

main()