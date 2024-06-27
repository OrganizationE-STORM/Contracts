import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'dotenv/config'
import "@nomicfoundation/hardhat-verify";

const ETHERSCAN_API_KEY = vars.get("ETHERSCAN_API_KEY");


const config: HardhatUserConfig = {
  defaultNetwork: "amoy",
  solidity: "0.8.24",
  networks: {
    amoy: {
      url: "https://rpc-amoy.polygon.technology",
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 80002
    }
  },
  etherscan: {
    apiKey: {
      polygonAmoy: ETHERSCAN_API_KEY
    },
  }
};

export default config;
