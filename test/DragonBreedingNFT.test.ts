import { ethers } from 'hardhat';
import { Contract, Signer } from 'ethers';
import { expect } from 'chai';

describe('DragonNftTest', function () {
	let operatorManager: Contract;
	let dragonNFT: Contract;
	let dragonRental: Contract;
	let dragonBreed: Contract;
	let testVRFv2Consumer: Contract;
	let testVRFCoordinatorV2Mock: Contract;
	let owner: Signer;
	let user1: Signer;
	let user2: Signer;

	const maxLevel = 100;
	let xpToLevelUp = [10000];

	const rarityBasedExperience = [10, 12, 14, 16, 18, 20];
	const speciesCountPerRarity = [8, 5, 4, 3, 2, 1];
	const rarityBasedDamage = [50, 100, 170, 300, 450, 700];

	for (let i = 1; i < maxLevel; i++) {
		let increaseRate;

		increaseRate = i < 50 ? 1.1 : 1.2; // 레벨 1~50: 1.1배 증가 51~100: 1.2배 증가

		let nextXp = Math.ceil(xpToLevelUp[i - 1] * increaseRate);
		xpToLevelUp.push(nextXp);
	}

	before(async () => {
		const OperatorManager = await ethers.getContractFactory('OperatorManager');
		const DragonNFT = await ethers.getContractFactory('DragonNFT');
		const DragonRental = await ethers.getContractFactory('DragonRental');
		const DragonBreed = await ethers.getContractFactory('DragonBreed');
		const TestVRFv2Consumer = await ethers.getContractFactory('TestVRFv2Consumer');
		const TestVRFCoordinatorV2Mock = await ethers.getContractFactory('TestVRFCoordinatorV2Mock');

		[owner, user1, user2] = await ethers.getSigners();

		operatorManager = await OperatorManager.connect(owner).deploy();
		await operatorManager.deployed();

		dragonNFT = await DragonNFT.connect(owner).deploy(maxLevel, xpToLevelUp, operatorManager.address);
		await dragonNFT.deployed();

		dragonRental = await DragonRental.connect(owner).deploy(dragonNFT.address, operatorManager.address);
		await dragonRental.deployed();

		dragonBreed = await DragonBreed.connect(owner).deploy(dragonNFT.address, dragonRental.address, operatorManager.address);
		await dragonBreed.deployed();

		testVRFCoordinatorV2Mock = await TestVRFCoordinatorV2Mock.connect(owner).deploy();
		await testVRFCoordinatorV2Mock.deployed();

		const transactionCreate = await testVRFCoordinatorV2Mock.connect(owner).createSubscription();
		const receiptTxCreate = await transactionCreate.wait();
		const subscriptionEvent = receiptTxCreate.events.find((e: any) => e.event === 'SubscriptionCreated');

		const transactionFund = await testVRFCoordinatorV2Mock.connect(owner).fundSubscription(subscriptionEvent.args.subId, ethers.utils.parseEther('100'));
		await transactionFund.wait();

		testVRFv2Consumer = await TestVRFv2Consumer.deploy(subscriptionEvent.args.subId, dragonNFT.address, dragonRental.address, dragonBreed.address, testVRFCoordinatorV2Mock.address);
		await testVRFv2Consumer.deployed();

		const transactionAddConsumer = await testVRFCoordinatorV2Mock.addConsumer(subscriptionEvent.args.subId, testVRFv2Consumer.address);
		await transactionAddConsumer.wait();

		await operatorManager.addOperator(testVRFv2Consumer.address);
		await operatorManager.addOperator(dragonBreed.address);
	});

	describe('DragonNFT', () => {
		it('Should be able to deploy', async () => {
			const contractRarityBasedExperience = await dragonNFT.getRarityBasedExperience();
			let isEqual = rarityBasedExperience.length === contractRarityBasedExperience.length && rarityBasedExperience.every((value, index) => value === contractRarityBasedExperience[index]);
			expect(isEqual).to.be.true;

			const contractSpeciesCountPerRarity = await dragonNFT.getSpeciesCountPerRarity();
			isEqual = speciesCountPerRarity.length === contractSpeciesCountPerRarity.length && speciesCountPerRarity.every((value, index) => value === contractSpeciesCountPerRarity[index]);
			expect(isEqual).to.be.true;

			const contractRarityBasedDamage = await dragonNFT.getRarityBasedDamage();
			isEqual = rarityBasedDamage.length === contractRarityBasedDamage.length && rarityBasedDamage.every((value, index) => value === contractRarityBasedDamage[index]);
			expect(isEqual).to.be.true;
		});
	});

	describe('VRFv2Consumer', () => {
		it('Should be able to deploy', async () => {
			const transactionMint = await testVRFv2Consumer.connect(owner).mintNewDragon({ value: ethers.utils.parseEther('1') });
			const receiptTxMint = await transactionMint.wait();
			const requestSentEvent = receiptTxMint.events.find((e: any) => e.event === 'RequestSent');

			const transactionRandomWords = await testVRFCoordinatorV2Mock.fulfillRandomWords(requestSentEvent.args.requestId, testVRFv2Consumer.address);
			await transactionRandomWords.wait();

			const balance = await dragonNFT.balanceOf(owner.getAddress());
			expect(balance).to.equal(1);

			const ownedDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
			expect(ownedDragon.length).to.equal(1);

			await dragonNFT.connect(owner).safeTransferFrom(owner.getAddress(), user1.getAddress(), ownedDragon[0]);
		});
	});
});
