import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat"; // Import Typechain plugin

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  typechain: {
    outDir: "typechain-types", // Output folder for generated types
    target: "ethers-v6",       // Use ethers.js v6 typings
  },
};

export default config;
