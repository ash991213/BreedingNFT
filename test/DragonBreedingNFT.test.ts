import { ethers } from 'hardhat';
import { Contract, Signer } from 'ethers';
import { expect } from 'chai';
import { time } from 'openzeppelin-test-helpers';

async function timeIncreaseTo(seconds: number) {
	const delay = 1000 - new Date().getMilliseconds();
	await new Promise((resolve) => setTimeout(resolve, delay));
	await time.increaseTo(seconds);
}

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

		[owner, user1, user2] = await ethers.getSigners();

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
	});

	describe('DragonNFT', () => {
		it('should match the rarity-based experience values with contract', async () => {
			const contractRarityBasedExperience = await dragonNFT.getRarityBasedExperience();
			const isEqual = rarityBasedExperience.length === contractRarityBasedExperience.length && rarityBasedExperience.every((value, index) => value === contractRarityBasedExperience[index]);
			expect(isEqual).to.be.true;
		});

		it('should match the species count per rarity with contract', async () => {
			const contractSpeciesCountPerRarity = await dragonNFT.getSpeciesCountPerRarity();
			const isEqual = speciesCountPerRarity.length === contractSpeciesCountPerRarity.length && speciesCountPerRarity.every((value, index) => value === contractSpeciesCountPerRarity[index]);
			expect(isEqual).to.be.true;
		});

		it('should match the rarity-based damage values with contract', async () => {
			const contractRarityBasedDamage = await dragonNFT.getRarityBasedDamage();
			let isEqual = rarityBasedDamage.length === contractRarityBasedDamage.length && rarityBasedDamage.every((value, index) => value === contractRarityBasedDamage[index]);
			expect(isEqual).to.be.true;
		});
	});

	describe('VRFv2Consumer', () => {
		it('should mint a new dragon successfully', async () => {
			const transactionMint = await testVRFv2Consumer.connect(owner).mintNewDragon({ value: ethers.utils.parseEther('1') });
			const receiptTxMint = await transactionMint.wait();
			const requestSentEvent = receiptTxMint.events.find((e: any) => e.event === 'RequestSent');

			const transactionRandomWords = await testVRFCoordinatorV2Mock.fulfillRandomWords(requestSentEvent.args.requestId, testVRFv2Consumer.address);
			await transactionRandomWords.wait();

			const ownersBalance = await dragonNFT.balanceOf(owner.getAddress());
			const ownersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
			expect(ownersBalance).to.be.equal(1);
			expect(ownersDragon.length).to.be.equal(1);
		});

		it('should transfer a dragon from owner to user1', async () => {
			const [ownersDragon] = await dragonNFT.getOwnedTokens(owner.getAddress());
			await dragonNFT.connect(owner).transferFrom(owner.getAddress(), user1.getAddress(), ownersDragon);

			const user1Balance = await dragonNFT.balanceOf(user1.getAddress());
			const user1Dragon = await dragonNFT.getOwnedTokens(user1.getAddress());
			expect(user1Balance).to.be.equal(1);
			expect(user1Dragon.length).to.be.equal(1);
		});

		it('should retrieve correct dragon information after transfer', async () => {
			const [user1Dragon] = await dragonNFT.getOwnedTokens(user1.getAddress());
			const dragonInfo = await dragonNFT.getDragonInfo(user1Dragon);

			expect(dragonInfo.gender).to.satisfy((num: number) => num >= 0 && num < 2);
			expect(dragonInfo.rarity).to.satisfy((num: number) => num >= 0 && num < 2);
			expect(dragonInfo.specie).to.satisfy((num: number) => num >= 0 && num < 13);
			expect(dragonInfo.level).to.be.equal(1);
			expect(dragonInfo.xp).to.be.equal(0);
			expect(dragonInfo.damage).to.satisfy((num: number) => num >= 50 && num < 151);
			expect(dragonInfo.xpPerSec).to.satisfy((num: number) => num === 10 || num === 12);
		});

		it('should correctly calculate and add experience for one hour', async () => {
			const timeDeposited = await time.latest();
			await timeIncreaseTo(timeDeposited.add(time.duration.hours(1)).subn(1));

			const [user1Dragon] = await dragonNFT.getOwnedTokens(user1.getAddress());
			const dragon = await dragonNFT.getDragonInfo(user1Dragon);

			const xpForOneHour = dragon.xpPerSec * 3600;

			let totalLevelsGained = 0;
			let xpNeededForNextLevel = xpToLevelUp[dragon.level - 1];
			let xpRemaining = xpForOneHour;

			while (xpRemaining >= xpNeededForNextLevel && dragon.level + totalLevelsGained < maxLevel) {
				xpRemaining -= xpNeededForNextLevel;
				totalLevelsGained++;
				if (dragon.level + totalLevelsGained < maxLevel) {
					xpNeededForNextLevel = xpToLevelUp[dragon.level + totalLevelsGained - 1];
				}
			}

			const dragonLevel = dragon.level + totalLevelsGained;

			const transactionAddExp = await dragonNFT.connect(user1).addExperience(user1Dragon);
			const receiptTxAddExp = await transactionAddExp.wait();
			const dragonExperienceGainedEvent = receiptTxAddExp.events.find((e: any) => e.event === 'DragonExperienceGained');

			expect(dragonExperienceGainedEvent.args._tokenId).to.be.equal(user1Dragon);
			expect(dragonExperienceGainedEvent.args._xp).to.be.equal(0);
			expect(dragonExperienceGainedEvent.args._level).to.be.equal(dragonLevel);
			// ? 103번째 줄에서 드래곤을 발행하고 다른 테스트가 순차적으로 진행됨에 따라 1~10초 정도 약간의 시간차가 발생할 수 있음 따라서 조건에 dragon.xpPerSec * 10을 추가함
			expect(dragonExperienceGainedEvent.args._xpToAdd).to.satisfy((num: number) => num >= xpForOneHour && num < xpForOneHour + dragon.xpPerSec * 10);
		});

		it('should correctly set experience required for next level and emit event', async () => {
			const newXp = 1000;
			const transactionSetXp = await dragonNFT.connect(owner).setXpToLevelUp(1, newXp);
			const receiptTxSetXp = await transactionSetXp.wait();
			const dragonLevelXPAdjustedEvent = receiptTxSetXp.events.find((e: any) => e.event === 'DragonLevelXPAdjusted');

			expect(dragonLevelXPAdjustedEvent.args.previousXP).to.be.equal(xpToLevelUp[0]);
			expect(dragonLevelXPAdjustedEvent.args.newXP).to.be.equal(1000);
		});
	});

	describe('DragonRental', () => {
		it('should correctly mark a dragon as rented upon successful rental', async () => {
			const [user1Dragon] = await dragonNFT.getOwnedTokens(user1.getAddress());
			const transactionRentDragon = await dragonRental.connect(user1).rentDragon(user1Dragon);
			await transactionRentDragon.wait();
			const transactionGetDragonRental = await dragonRental.getDragonRental(user1Dragon);

			expect(transactionGetDragonRental.isRented).to.be.equal(true);
			expect(transactionGetDragonRental.renter).to.be.equal(await user1.getAddress());
			expect(transactionGetDragonRental.duration - transactionGetDragonRental.startTime).to.be.equal(172800);
		});

		it('should confirm that a rental is active for a dragon', async () => {
			const [user1Dragon] = await dragonNFT.getOwnedTokens(user1.getAddress());
			const isRentalActive = await dragonRental.connect(user1).isRentalActive(user1Dragon);
			expect(isRentalActive).to.be.equal(true);
		});

		it('should retrieve the list of currently rented dragons', async () => {
			const [user1Dragon] = await dragonNFT.getOwnedTokens(user1.getAddress());
			const [rentedDragon] = await dragonRental.getCurrentlyRentedDragons();
			expect(rentedDragon).to.be.equal(user1Dragon);
		});

		it('should cancel a dragon rental and emit the appropriate event', async () => {
			const [user1Dragon] = await dragonNFT.getOwnedTokens(user1.getAddress());
			const transactionCancelRental = await dragonRental.connect(user1).cancelRental(user1Dragon);
			const receiptCancelRental = await transactionCancelRental.wait();
			const DragonRentalCancelledEvent = receiptCancelRental.events.find((e: any) => e.event === 'DragonRentalCancelled');
			expect(DragonRentalCancelledEvent.args.tokenId).to.be.equal(user1Dragon);
			expect(DragonRentalCancelledEvent.args.renter).to.be.equal(await user1.getAddress());
		});
	});

	describe('DragonBreed', () => {
		beforeEach(async () => {
			const [user1Dragon] = await dragonNFT.getOwnedTokens(user1.getAddress());
			const transactionRentDragon = await dragonRental.connect(user1).rentDragon(user1Dragon);
			await transactionRentDragon.wait();

			const dragonInfo = await dragonNFT.getDragonInfo(user1Dragon);

			const dragon1Gender = dragonInfo.gender;
			let dragon2Gender;

			while (dragon1Gender === dragon2Gender) {
				const transactionMint = await testVRFv2Consumer.connect(owner).mintNewDragon({ value: ethers.utils.parseEther('1') });
				const receiptTxMint = await transactionMint.wait();
				const requestSentEvent = receiptTxMint.events.find((e: any) => e.event === 'RequestSent');

				const transactionRandomWords = await testVRFCoordinatorV2Mock.fulfillRandomWords(requestSentEvent.args.requestId, testVRFv2Consumer.address);
				await transactionRandomWords.wait();
				const ownerDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
				const dragonInfo = await dragonNFT.getDragonInfo(ownerDragon[ownerDragon.length - 1]);
				dragon2Gender = dragonInfo.gender;
			}
		});

		it('breedDragons', async () => {
			const beforeOwnersBalance = await dragonNFT.balanceOf(owner.getAddress());
			const beforeOwnersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());

			const ownersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
			const [user1Dragon] = await dragonNFT.getOwnedTokens(user1.getAddress());

			const dragonInfo1 = await dragonNFT.getDragonInfo(ownersDragon.length - 1);
			const dragonInfo2 = await dragonNFT.getDragonInfo(user1Dragon);

			console.log(dragonInfo1.rarity);
			console.log(dragonInfo2.rarity);

			const transactionBreed = await testVRFv2Consumer.connect(owner).breedDragons(ownersDragon[ownersDragon.length - 1], user1Dragon, { value: ethers.utils.parseEther('1') });
			const receiptTxBreed = await transactionBreed.wait();
			const requestSentEvent = receiptTxBreed.events.find((e: any) => e.event === 'RequestSent');

			const transactionRandomWords = await testVRFCoordinatorV2Mock.fulfillRandomWords(requestSentEvent.args.requestId, testVRFv2Consumer.address);
			await transactionRandomWords.wait();

			const afterOwnersBalance = await dragonNFT.balanceOf(owner.getAddress());
			const afterOwnersDragon = await dragonNFT.getOwnedTokens(owner.getAddress());

			expect(beforeOwnersBalance).to.be.equal(afterOwnersBalance - 1);
			console.log(beforeOwnersBalance);
			console.log(afterOwnersBalance);
			expect(beforeOwnersDragon.length).to.be.equal(afterOwnersDragon.length - 1);
			console.log(beforeOwnersDragon);
			console.log(afterOwnersDragon);
		});

		it('breedDragon info', async () => {
			const ownersNewDragon = await dragonNFT.getOwnedTokens(owner.getAddress());
			console.log(ownersNewDragon);
			// const dragonInfo = await dragonNFT.getDragonInfo(ownersNewDragon);

			// console.log(dragonInfo.rarity);

			// expect(dragonInfo.gender).to.satisfy((num: number) => num >= 0 && num < 2);
			// expect(dragonInfo.rarity).to.satisfy((num: number) => num >= 0 && num < 3);
			// expect(dragonInfo.specie).to.satisfy((num: number) => num >= 0 && num < 17);
			// expect(dragonInfo.level).to.be.equal(1);
			// expect(dragonInfo.xp).to.be.equal(0);
			// expect(dragonInfo.damage).to.satisfy((num: number) => num >= 50 && num < 321);
			// expect(dragonInfo.xpPerSec).to.satisfy((num: number) => num === 10 || num === 12 || num === 14);
		});
	});
});
