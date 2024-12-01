import { ethers } from "hardhat";

async function main() {
    const reputationContractFactory = await ethers.getContractFactory("ReputationStateMachine");
    const reputationContract = await reputationContractFactory.deploy();
    await reputationContract.waitForDeployment();
    console.log("ReputationStateMachine deployed to:", await reputationContract.getAddress());
}

// Run the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
