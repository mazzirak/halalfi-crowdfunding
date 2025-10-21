const { ethers } = require("hardhat");
const { writeFileSync } = require("fs");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    // Deploy CrowdfundAdmin
    const CrowdfundAdmin = await ethers.getContractFactory("CrowdfundAdmin");
    const crowdfundAdmin = await CrowdfundAdmin.deploy();
    await crowdfundAdmin.deployed();
    console.log("CrowdfundAdmin deployed to:", crowdfundAdmin.address);
    
    
    
    // Deploy CrowdfundFactory
    const CrowdfundFactory = await ethers.getContractFactory("CrowdfundFactory");
    const crowdfundFactory = await CrowdfundFactory.deploy();
    await crowdfundFactory.deployed();
    console.log("CrowdfundFactory deployed to:", crowdfundFactory.address);

    if (!(await crowdfundAdmin.isAdmin(deployer.address))) {
        console.log("Adding deployer as admin...");
        const tx = await crowdfundAdmin.addAdmin(deployer.address);
        await tx.wait();
        console.log("Deployer added as admin");
    }
    
    
    // Save contract addresses and ABIs
    const contracts = {
        CrowdfundAdmin: {
            address: crowdfundAdmin.address,
            abi: JSON.parse(crowdfundAdmin.interface.format("json")),
        },
        CrowdfundFactory: {
            address: crowdfundFactory.address,
            abi: JSON.parse(crowdfundFactory.interface.format("json")),
        },
    };

    // Write addresses file
    writeFileSync(
        "./client/src/contracts/addresses.js",
        `export const addresses = ${JSON.stringify(
            {
                CrowdfundAdmin: crowdfundAdmin.address,
                CrowdfundFactory: crowdfundFactory.address,
            },
            null,
            2
        )}`
    );

    // Write ABIs files
    writeFileSync(
        "./client/src/contracts/abis/CrowdfundAdmin.json",
        JSON.stringify(contracts.CrowdfundAdmin, null, 2)
    );
    writeFileSync(
        "./client/src/contracts/abis/CrowdfundFactory.json",
        JSON.stringify(contracts.CrowdfundFactory, null, 2)
    );
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
