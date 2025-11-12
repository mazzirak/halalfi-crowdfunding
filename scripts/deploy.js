const {ethers} = require("hardhat");
const {writeFileSync, mkdirSync} = require("fs");
const path = require("path");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()));

    // For localhost testing, deploy Mock USDT
    // For mainnet/testnet, use real USDT address
    const network = await ethers.provider.getNetwork();
    let USDT_ADDRESS;

    if (network.chainId === 31337) {
        // Localhost - Deploy Mock USDT
        console.log("\n--- Deploying Mock USDT for Testing ---");
        const MockUSDT = await ethers.getContractFactory("MockUSDT");
        const mockUSDT = await MockUSDT.deploy();
        await mockUSDT.deployed();
        USDT_ADDRESS = mockUSDT.address;
        console.log("Mock USDT deployed to:", USDT_ADDRESS);

        // Mint some USDT for testing
        const mintAmount = ethers.utils.parseUnits("1000000", 6); // 1M USDT
        await mockUSDT.mint(deployer.address, mintAmount);
        console.log("Minted 1,000,000 USDT to deployer for testing");
    } else {
        // Use real USDT address for other networks
        // Ethereum Mainnet: 0xdAC17F958D2ee523a2206206994597C13D831ec7
        USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        console.log("Using USDT address:", USDT_ADDRESS);
    }

    // Step 1: Deploy CrowdfundAdmin
    console.log("\n--- Deploying CrowdfundAdmin ---");
    const CrowdfundAdmin = await ethers.getContractFactory("CrowdfundAdmin");
    const crowdfundAdmin = await CrowdfundAdmin.deploy();
    await crowdfundAdmin.deployed();
    console.log("CrowdfundAdmin deployed to:", crowdfundAdmin.address);

    // Step 2: Deploy CrowdfundFactory
    console.log("\n--- Deploying CrowdfundFactory ---");
    const CrowdfundFactory = await ethers.getContractFactory("CrowdfundFactory");
    const crowdfundFactory = await CrowdfundFactory.deploy(
        USDT_ADDRESS,           // Payment token (USDT)
        crowdfundAdmin.address  // Admin contract address
    );
    await crowdfundFactory.deployed();
    console.log("CrowdfundFactory deployed to:", crowdfundFactory.address);

    // Step 3: Verify admin setup
    console.log("\n--- Verifying Admin Setup ---");
    const isDeployerAdmin = await crowdfundAdmin.checkAdmin(deployer.address);
    console.log("Is deployer admin?", isDeployerAdmin);

    if (!isDeployerAdmin) {
        console.log("ERROR: Deployer should be admin by default!");
    }

    // Step 4: Verify factory setup
    console.log("\n--- Verifying Factory Setup ---");
    const factoryAdmin = await crowdfundFactory.getAdmin();
    const factoryPaymentToken = await crowdfundFactory.paymentToken();
    console.log("Factory admin contract:", factoryAdmin);
    console.log("Factory payment token:", factoryPaymentToken);

    // Verify addresses match
    if (factoryAdmin !== crowdfundAdmin.address) {
        console.log("ERROR: Factory admin address doesn't match deployed admin!");
    }
    if (factoryPaymentToken !== USDT_ADDRESS) {
        console.log("ERROR: Factory payment token doesn't match USDT address!");
    }

    // Step 5: Create directories for contract data
    const clientDir = "./client/src/contracts";
    const abisDir = "./client/src/contracts/abis";

    try {
        mkdirSync(clientDir, { recursive: true });
        mkdirSync(abisDir, { recursive: true });
    } catch (error) {
        // Directories might already exist
    }

    // Step 6: Get contract ABIs
    console.log("\n--- Preparing Contract Data ---");
    const CrowdfundProject = await ethers.getContractFactory("CrowdfundProject");

    // Step 7: Write addresses file
    console.log("\n--- Saving Contract Data ---");
    writeFileSync(
        path.join(clientDir, "addresses.js"),
        `export const addresses = ${JSON.stringify(
            {
                CrowdfundAdmin: crowdfundAdmin.address,
                CrowdfundFactory: crowdfundFactory.address,
                USDT: USDT_ADDRESS,
            },
            null,
            2
        )};

export const networkConfig = {
    USDT_ADDRESS: "${USDT_ADDRESS}",
    PLATFORM_FEE_PERCENT: 1,
    CREATOR_WITHDRAWAL_DEADLINE_DAYS: 7,
    CHAIN_ID: ${network.chainId},
    NETWORK_NAME: "${network.name}",
};`
    );

    // Step 8: Write ABIs files
    writeFileSync(
        path.join(abisDir, "CrowdfundAdmin.json"),
        JSON.stringify(crowdfundAdmin.interface.fragments, null, 2)
    );

    writeFileSync(
        path.join(abisDir, "CrowdfundFactory.json"),
        JSON.stringify(crowdfundFactory.interface.fragments, null, 2)
    );

    writeFileSync(
        path.join(abisDir, "CrowdfundProject.json"),
        JSON.stringify(CrowdfundProject.interface.fragments, null, 2)
    );

    // Step 9: Write deployment summary
    const deploymentSummary = {
        network: {
            name: network.name,
            chainId: network.chainId,
        },
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: {
            CrowdfundAdmin: crowdfundAdmin.address,
            CrowdfundFactory: crowdfundFactory.address,
            USDT: USDT_ADDRESS,
        },
        configuration: {
            platformFeePercent: 1,
            creatorWithdrawalDeadlineDays: 7,
        },
        nextSteps: [
            network.chainId === 31337
                ? "Using Mock USDT for local testing"
                : "Update USDT_ADDRESS for your network",
            "Test project creation and investment flow",
            network.chainId !== 31337 ? "Verify all contracts on block explorer" : "Connect MetaMask to localhost",
        ]
    };

    writeFileSync(
        "./deployment-summary.json",
        JSON.stringify(deploymentSummary, null, 2)
    );

    console.log("\n=== Deployment Summary ===");
    console.log("Network:", network.name, `(Chain ID: ${network.chainId})`);
    console.log("CrowdfundAdmin:", crowdfundAdmin.address);
    console.log("CrowdfundFactory:", crowdfundFactory.address);
    console.log("USDT Token:", USDT_ADDRESS);
    console.log("Platform Fee:", "1%");
    console.log("Creator Withdrawal Deadline:", "7 days");

    if (network.chainId === 31337) {
        console.log("\n=== Localhost Testing Setup ===");
        console.log("1. Add localhost network to MetaMask:");
        console.log("   - Network Name: Hardhat Local");
        console.log("   - RPC URL: http://127.0.0.1:8545");
        console.log("   - Chain ID: 31337");
        console.log("   - Currency Symbol: ETH");
        console.log("");
        console.log("2. Import test account to MetaMask:");
        console.log("   - Address:", deployer.address);
        console.log("   - Check hardhat node terminal for private key");
        console.log("");
        console.log("3. Add Mock USDT to MetaMask:");
        console.log("   - Token Address:", USDT_ADDRESS);
        console.log("   - Symbol: USDT");
        console.log("   - Decimals: 6");
    } else {
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Test project creation and investment flow");
        console.log("3. Update frontend with deployed addresses");
    }

    console.log("\n=== Files Created ===");
    console.log("✅ ./client/src/contracts/addresses.js");
    console.log("✅ ./client/src/contracts/abis/CrowdfundAdmin.json");
    console.log("✅ ./client/src/contracts/abis/CrowdfundFactory.json");
    console.log("✅ ./client/src/contracts/abis/CrowdfundProject.json");
    console.log("✅ ./deployment-summary.json");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });