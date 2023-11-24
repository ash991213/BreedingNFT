import { ethers } from 'hardhat';

async function main() {
	const subscriptionId = 6889;
	const maxLevel = 5;
	let xpToLevelUp = [1000];

	for (let i = 1; i < maxLevel; i++) {
		let increaseRate = i < 6 ? 1.1 : 1.2; // 레벨 6 이하와 이상에 대한 증가율 구분
		xpToLevelUp.push(Math.ceil(xpToLevelUp[i - 1] * increaseRate));
	}

	const DragonBreedingNFT = await ethers.getContractFactory('DragonBreedingNFT');

	const dragonBreedingNFT = await DragonBreedingNFT.deploy(subscriptionId, maxLevel, xpToLevelUp);
	await dragonBreedingNFT.deployed();

	console.log(`DragonBreedingNFT deployed to ${dragonBreedingNFT.address}`);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
