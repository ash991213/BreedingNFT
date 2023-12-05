// import { ethers } from 'hardhat';
// import { Contract, Signer } from 'ethers';
// import { expect } from 'chai';
// import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

// describe('DragonNftTest', function () {
// 	const maxLevel = 100;
// 	let xpToLevelUp = [10000];

// 	const rarityBasedExperience = [10, 12, 14, 16, 18, 20];
// 	const speciesCountPerRarity = [8, 5, 4, 3, 2, 1];
// 	const rarityBasedDamage = [50, 100, 170, 300, 450, 700];

// 	for (let i = 1; i < maxLevel; i++) {
// 		let increaseRate;

// 		increaseRate = i < 50 ? 1.1 : 1.2; // 레벨 1~50: 1.1배 증가 51~100: 1.2배 증가

// 		let nextXp = Math.ceil(xpToLevelUp[i - 1] * increaseRate);
// 		xpToLevelUp.push(nextXp);
// 	}

// 	async function deployContractsFixture() {
// 		let operatorManager: Contract;
// 		let dragonNFT: Contract;
// 		let dragonRental: Contract;
// 		let dragonBreed: Contract;
// 		let vrfv2Consumer: Contract;
// 		let contractForVrfTestingCode: Contract;
// 		let owner: Signer;
// 		let addr1: Signer;
// 		let addr2: Signer;

// 		const OperatorManager = await ethers.getContractFactory('OperatorManager');
// 		const DragonNFT = await ethers.getContractFactory('DragonNFT');
// 		const DragonRental = await ethers.getContractFactory('DragonRental');
// 		const DragonBreed = await ethers.getContractFactory('DragonBreed');
// 		const VRFv2Consumer = await ethers.getContractFactory('VRFv2Consumer');
// 		const ContractForVrfTestingCode = await ethers.getContractFactory('ContractForVrfTestingCode');

// 		[owner, addr1, addr2] = await ethers.getSigners();

// 		operatorManager = await OperatorManager.connect(owner).deploy();
// 		await operatorManager.deployed();

// 		dragonNFT = await DragonNFT.connect(owner).deploy(maxLevel, xpToLevelUp, operatorManager.address);
// 		await dragonNFT.deployed();

// 		dragonRental = await DragonRental.connect(owner).deploy(dragonNFT.address, operatorManager.address);
// 		await dragonRental.deployed();

// 		dragonBreed = await DragonBreed.connect(owner).deploy(dragonNFT.address, dragonRental.address, operatorManager.address);
// 		await dragonBreed.deployed();

// 		contractForVrfTestingCode = await ContractForVrfTestingCode.connect(owner).deploy();
// 		await contractForVrfTestingCode.deployed();

// 		const transaction = await contractForVrfTestingCode.connect(owner).createSubscription();
// 		const receiptTx = await transaction.wait();
// 		const subscriptionEvent = receiptTx.events.find((e: any) => e.event === 'SubscriptionCreated');

// 		const transactionFund = await contractForVrfTestingCode.connect(owner).fundSubscription(subscriptionEvent.args.subId, ethers.utils.parseEther('1'));
// 		await transactionFund.wait();

// 		vrfv2Consumer = await VRFv2Consumer.connect(owner).deploy(subscriptionEvent.args.subId, dragonNFT.address, dragonRental.address, dragonBreed.address, contractForVrfTestingCode.address);
// 		await vrfv2Consumer.deployed();

// 		const transactionAddConsumer = await contractForVrfTestingCode.addConsumer(subscriptionEvent.args.subId, vrfv2Consumer.address);
// 		await transactionAddConsumer.wait();

// 		return { operatorManager, dragonNFT, dragonRental, dragonBreed, contractForVrfTestingCode, vrfv2Consumer, owner, addr1, addr2 };
// 	}

// 	describe('DragonNFT', () => {
// 		it('Should be able to deploy', async () => {
// 			const { dragonNFT } = await loadFixture(deployContractsFixture);

// 			const contractRarityBasedExperience = await dragonNFT.getRarityBasedExperience();
// 			let isEqual = rarityBasedExperience.length === contractRarityBasedExperience.length && rarityBasedExperience.every((value, index) => value === contractRarityBasedExperience[index]);
// 			expect(isEqual).to.be.true;

// 			const contractSpeciesCountPerRarity = await dragonNFT.getSpeciesCountPerRarity();
// 			isEqual = speciesCountPerRarity.length === contractSpeciesCountPerRarity.length && speciesCountPerRarity.every((value, index) => value === contractSpeciesCountPerRarity[index]);
// 			expect(isEqual).to.be.true;

// 			const contractRarityBasedDamage = await dragonNFT.getRarityBasedDamage();
// 			isEqual = rarityBasedDamage.length === contractRarityBasedDamage.length && rarityBasedDamage.every((value, index) => value === contractRarityBasedDamage[index]);
// 			expect(isEqual).to.be.true;
// 		});
// 	});

// 	describe('VRFv2Consumer', () => {
// 		it('Should be able to deploy', async () => {
// 			// vrfv2Consumer;
// 		});
// 	});
// });
