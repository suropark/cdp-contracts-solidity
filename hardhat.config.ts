import * as dotenv from "dotenv";
dotenv.config();

import "@nomicfoundation/hardhat-network-helpers";
import "@nomiclabs/hardhat-waffle";
import "hardhat-deploy";
import { ethers } from "ethers";
import "hardhat-gas-reporter";
const { PRIVATE_KEY } = process.env;

const PVT = PRIVATE_KEY || ethers.Wallet.createRandom().privateKey;

const config = {
    solidity: {
        compilers: [
            {
                version: "0.8.17",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        hardhat: {
            accounts: [
                {
                    privateKey: PVT,
                    balance: "1000000000000000000000000000",
                },
            ],
            saveDeployments: false,
            tags: ["test", "local"],
        },

        mode_test: {
            url: "https://sepolia.mode.network",
            chainId: 919,
            accounts: [PVT!],
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
    gasReporter: {
        currency: "USD",
        gasPrice: 100,
        enabled: true,
    },

    // files
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
    },
};

export default config;
