import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'dotenv/config';

const config: HardhatUserConfig = {
	defaultNetwork: 'ganache',
	networks: {
		ganache: {
			url: `http://127.0.0.1:8545`,
			gas: 'auto',
			gasPrice: 10e9,
			blockGasLimit: 1500000000000,
		},
		sepolia: {
			url: `https://sepolia.infura.io/v3/${String(process.env.SEPOLIA_API_KEY)}`,
			accounts: [String(process.env.PRIVATE_KEY)],
			chainId: 11155111,
		},
	},
	etherscan: {
		// yarn hardhat verify --network <NETWORK> <CONTRACT_ADDRESS> <CONSTRUCTOR_PARAMETERS>
		apiKey: {
			// npx hardhat verify --list-networks
			mainnet: process.env.ETHERSCAN_API_KEY || '',
			sepolia: process.env.ETHERSCAN_API_KEY || '',
			polygon: process.env.ETHERSCAN_API_KEY || '',
			polygonMumbai: process.env.ETHERSCAN_API_KEY || '',
		},
	},
	gasReporter: {
		enabled: true,
		currency: 'USD',
		outputFile: 'gas-report.txt',
		noColors: true,
		// coinmarketcap: process.env.COINMARKETCAP_API_KEY,
	},
	solidity: {
		version: '0.8.20',
		settings: {
			optimizer: {
				enabled: true,
				runs: 1000000,
			},
			metadata: {
				bytecodeHash: 'none',
			},
		},
	},
	paths: {
		sources: './contracts',
		tests: './test',
		cache: './cache',
		artifacts: './artifacts',
	},
	mocha: {
		timeout: 300000,
	},
};

export default config;
