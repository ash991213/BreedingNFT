import { ethers } from 'hardhat';
import { Contract, Signer } from 'ethers';
import { expect } from 'chai';

describe('DragonBreed Test', async () => {
	let operatorManager: Contract;
	let dragonNFT: Contract;
	let dragonRental: Contract;
	let dragonBreed: Contract;
	let testVRFv2Consumer: Contract;
	let testVRFCoordinatorV2Mock: Contract;
	let owner: Signer;
	let user: Signer;

	const maxLevel = 100;
	let xpToLevelUp = [10000];

	for (let i = 1; i < maxLevel; i++) {
		let increaseRate;

		increaseRate = i < 50 ? 1.1 : 1.2;

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

		[owner, user] = await ethers.getSigners();

		operatorManager = await OperatorManager.connect(owner).deploy();
		await operatorManager.deployed();

		dragonNFT = await DragonNFT.connect(owner).deploy(maxLevel, xpToLevelUp, operatorManager.address);
		await dragonNFT.deployed();

		dragonRental = await DragonRental.connect(owner).deploy(operatorManager.address, dragonNFT.address);
		await dragonRental.deployed();

		dragonBreed = await DragonBreed.connect(owner).deploy(operatorManager.address, dragonNFT.address, dragonRental.address);
		await dragonBreed.deployed();

		testVRFCoordinatorV2Mock = await TestVRFCoordinatorV2Mock.connect(owner).deploy();
		await testVRFCoordinatorV2Mock.deployed();

		const transactionCreateSub = await testVRFCoordinatorV2Mock.connect(owner).createSubscription();
		const receiptTxCreateSub = await transactionCreateSub.wait();
		const subscriptionEvent = receiptTxCreateSub.events.find((e: any) => e.event === 'SubscriptionCreated');

		const transactionFundSub = await testVRFCoordinatorV2Mock.connect(owner).fundSubscription(subscriptionEvent.args.subId, ethers.utils.parseEther('100'));
		await transactionFundSub.wait();

		testVRFv2Consumer = await TestVRFv2Consumer.deploy(subscriptionEvent.args.subId, dragonNFT.address, dragonRental.address, dragonBreed.address, testVRFCoordinatorV2Mock.address);
		await testVRFv2Consumer.deployed();

		const transactionAddConsumer = await testVRFCoordinatorV2Mock.addConsumer(subscriptionEvent.args.subId, testVRFv2Consumer.address);
		await transactionAddConsumer.wait();

		await operatorManager.addOperator(testVRFv2Consumer.address);
		await operatorManager.addOperator(dragonBreed.address);

		const ownersDragonCreateTx = await dragonNFT.connect(owner).mintNewDragon(owner.getAddress(), [0, 0, 0, 0]);
		await ownersDragonCreateTx.wait();
		const usersDragonCreateTx = await dragonNFT.connect(owner).mintNewDragon(user.getAddress(), [1, 0, 0, 0]);
		await usersDragonCreateTx.wait();

		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const transactionRentDragon = await dragonRental.connect(user).rentDragon(userDragon);
		await transactionRentDragon.wait();

		const dragonInfo = await dragonNFT.getDragonInfo(userDragon);
		const dragon1Gender = dragonInfo.gender;
		let dragon2Gender;

		do {
			const transactionMint = await testVRFv2Consumer.connect(owner).mintNewDragon({ value: ethers.utils.parseEther('1') });
			const receiptTxMint = await transactionMint.wait();
			const requestSentEvent = receiptTxMint.events.find((e: any) => e.event === 'RequestSent');

			const transactionRandomWords = await testVRFCoordinatorV2Mock.fulfillRandomWords(requestSentEvent.args.requestId, testVRFv2Consumer.address);
			await transactionRandomWords.wait();

			const ownerDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
			const dragonInfo = await dragonNFT.getDragonInfo(ownerDragon[ownerDragon.length - 1]);
			dragon2Gender = dragonInfo.gender;
		} while (dragon1Gender === dragon2Gender);
	});

	it('should fail to breed dragons if caller is not an operator', async () => {
		const ownersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const randomWords = [0, 0, 0, 0];
		const rentedDragonTokenId = await dragonNFT.totalSupply();

		await expect(dragonBreed.connect(user).breedDragons(user.getAddress(), ownersDragon[ownersDragon.length - 1], userDragon, randomWords, rentedDragonTokenId)).to.be.revertedWith('DragonBreedingNFT : msg.sender is no a valid operator');
	});

	it('should fail to distribute breeding fee if caller is not an operator', async () => {
		const ownersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());

		await expect(dragonBreed.connect(user).distributeBreedingFee(ownersDragon[ownersDragon.length - 1], userDragon)).to.be.revertedWith('DragonBreedingNFT : msg.sender is no a valid operator');
	});

	it('should successfully breed dragons and update breeding times and balances', async () => {
		const beforeOwnersBalance = await dragonNFT.balanceOf(owner.getAddress());
		const beforeOwnersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());

		const ownersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());

		const transactionBreed = await testVRFv2Consumer.connect(owner).breedDragons(ownersDragon[ownersDragon.length - 1], userDragon, { value: ethers.utils.parseEther('1') });
		const receiptTxBreed = await transactionBreed.wait();
		const requestSentEvent = receiptTxBreed.events.find((e: any) => e.event === 'RequestSent');

		const transactionRandomWords = await testVRFCoordinatorV2Mock.fulfillRandomWords(requestSentEvent.args.requestId, testVRFv2Consumer.address);
		const receiptRandomWords = await transactionRandomWords.wait();
		const timestamp = (await ethers.provider.getBlock(receiptRandomWords.blockNumber)).timestamp;

		const afterOwnersBalance = await dragonNFT.balanceOf(owner.getAddress());
		const afterOwnersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());

		const parents1LastBreedingTime = await dragonBreed.getLastBreedingTime(ownersDragon[ownersDragon.length - 1]);
		const parents2LastBreedingTime = await dragonBreed.getLastBreedingTime(userDragon);

		expect(parents1LastBreedingTime).to.be.equal(timestamp);
		expect(parents2LastBreedingTime).to.be.equal(timestamp);

		expect(beforeOwnersBalance).to.be.equal(afterOwnersBalance - 1);
		expect(beforeOwnersDragon.length).to.be.equal(afterOwnersDragon.length - 1);
	});

	it('should verify new dragon attributes post-breeding', async () => {
		const ownersNewDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
		const dragonInfo = await dragonNFT.getDragonInfo(ownersNewDragon[ownersNewDragon.length - 1]);

		expect(dragonInfo.gender).to.satisfy((num: number) => num >= 0 && num < 2);
		expect(dragonInfo.rarity).to.satisfy((num: number) => num >= 0 && num < 3);
		expect(dragonInfo.specie).to.satisfy((num: number) => num >= 0 && num < 17);
		expect(dragonInfo.level).to.be.equal(1);
		expect(dragonInfo.xp).to.be.equal(0);
		expect(dragonInfo.damage).to.satisfy((num: number) => num >= 50 && num < 321);
		expect(dragonInfo.xpPerSec).to.satisfy((num: number) => num === 10 || num === 12 || num === 14);
	});

	it('should return 0 for last breeding time of a non-existing dragon', async () => {
		const nonExistingTokenId = 999;

		const lastBreedingTime = await dragonBreed.getLastBreedingTime(nonExistingTokenId);
		expect(lastBreedingTime).to.be.equal(0);
	});
});
