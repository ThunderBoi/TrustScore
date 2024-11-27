import ReputationStateMachineABI from "./artifacts/contracts/trustScore.sol/ReputationStateMachine.json";
const ethers = require("ethers");

// Connect to the local Ethereum simulation
const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");

const CONTRACT_ADDRESS = "0x5fbdb2315678afecb367f032d93f642f64180aa3";

// Initialize the contract instance
const contract = new ethers.Contract(CONTRACT_ADDRESS, ReputationStateMachineABI.abi, provider.getSigner());

export default contract;
