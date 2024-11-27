import { ethers } from "hardhat";
import { ReputationStateMachine } from "../typechain-types";

async function main() {
    // Get the contract factory with typings
    const ReputationStateMachineFactory = await ethers.getContractFactory("ReputationStateMachine");
    const reputationContract = (await ReputationStateMachineFactory.deploy()) as ReputationStateMachine;

    // Wait for the deployment transaction to complete
    const deploymentTransaction = reputationContract.deploymentTransaction();
    if (deploymentTransaction) {
        await deploymentTransaction.wait();
    } else {
        throw new Error("Deployment transaction is null");
    }
    // Log the deployed contract's address
    console.log("ReputationStateMachine deployed to:", reputationContract.target);
}

// Run the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
