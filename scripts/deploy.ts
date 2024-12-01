import { ethers } from "hardhat";
import { ReputationStateMachine } from "../typechain-types";

async function main() {
    // Get the contract factory with typings
    const ReputationStateMachineFactory = await ethers.getContractFactory("ReputationStateMachine");
    const reputationContract = (await ReputationStateMachineFactory.deploy()) as ReputationStateMachine;

    // Wait for the deployment transaction to complete
    const deployTransaction = reputationContract.deployTransaction;
    if (deployTransaction) {
        await deployTransaction.wait();
    } else {
        throw new Error("Deployment transaction is null");
    }
    // Log the deployed contract's address
    console.log("ReputationStateMachine deployed to:", reputationContract.address);
}

// Run the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
