const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require('hardhat');
const { Test } = require("mocha");

describe("TEsting contract deployer", function (){
    it("testing", async function test(){
        try { 
            const GTD = await ethers.getContractFactory("GovernanceTokenDeployer");
            const GovernorTokenDeployer = await GTD.deploy();
            await GovernorTokenDeployer.deployed();

            const GCMD = await ethers.getContractFactory("GovernorContractMultiDeployer");
            const GovConMulDep = await GCMD.deploy();
            await GovConMulDep.deployed();

            const TLMD = await ethers.getContractFactory("TimeLockMultiDeployer");
            const TimeLockMultiD = await TLMD.deploy();
            await TimeLockMultiD.deployed();

            const VL = await ethers.getContractFactory("TimeLock");
            const TimeLock = await VL.deploy();
            await TimeLock.deployed();

            const contractDeployer = await ethers.getContractFactory("SystemDeployer");
            const SystemDeployer = await contractDeployer.deploy(TimeLock.address);
            await SystemDeployer.deployed();

            console.log("Contract deployer", SystemDeployer.address);
            console.log("governor token", GovernorTokenDeployer.address);
            console.log("timelock d", TimeLockMultiD.address);
            console.log("governor", GovConMulDep.address);

            await SystemDeployer.setDeployers(
                GovernorTokenDeployer.address,
                TimeLockMultiD.address,
                GovConMulDep.address
            );
            
            const tx = await SystemDeployer.deploySystem(
                [1, [ethers.constants.AddressZero], [ethers.constants.AddressZero]]
            );

            await SystemDeployer.setUpContracts();

        } catch(err) {
            console.log(err);
        }
    })
})