import { ethers } from 'hardhat';

async function main() {
	const subscriptionId = 6889;
	const maxLevel = 100;
	let xpToLevelUp = [100000];

	for (let i = 1; i < maxLevel; i++) {
		let increaseRate;

		increaseRate = i < 50 ? 1.1 : 1.2; // 레벨 1~50: 1.1배 증가 51~100: 1.2배 증가

		let nextXp = Math.ceil(xpToLevelUp[i - 1] * increaseRate);
		xpToLevelUp.push(nextXp);
	}

	const OperatorManager = await ethers.getContractFactory('OperatorManager');
	const operatorManager = await OperatorManager.deploy();
	await operatorManager.deployed();

	const DragonNFT = await ethers.getContractFactory('DragonNFT');
	const dragonNFT = await DragonNFT.deploy(maxLevel, xpToLevelUp, operatorManager.address);
	await dragonNFT.deployed();

	const DragonRental = await ethers.getContractFactory('DragonRental');
	const dragonRental = await DragonRental.deploy(dragonNFT.address, operatorManager.address);
	await dragonRental.deployed();

	const DragonBreed = await ethers.getContractFactory('DragonBreed');
	const dragonBreed = await DragonBreed.deploy(dragonNFT.address, dragonRental.address, operatorManager.address);
	await dragonBreed.deployed();

	const VRFv2Consumer = await ethers.getContractFactory('VRFv2Consumer');
	const vRFv2Consumer = await VRFv2Consumer.deploy(subscriptionId, dragonNFT.address, dragonRental.address, dragonBreed.address);
	await vRFv2Consumer.deployed();

	console.log(`OperatorManager deployed to ${operatorManager.address}`);
	console.log(`DragonNFT deployed to ${dragonNFT.address}`);
	console.log(`DragonRental deployed to ${dragonRental.address}`);
	console.log(`DragonBreed deployed to ${dragonBreed.address}`);
	console.log(`VRFv2Consumer deployed to ${vRFv2Consumer.address}`);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
