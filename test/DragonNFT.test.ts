import { ethers } from 'hardhat';
import { Contract, Signer } from 'ethers';
import { expect } from 'chai';
import { time } from '@nomicfoundation/hardhat-network-helpers';

describe('DragonNFT', async () => {
	let operatorManager: Contract;
	let dragonNFT: Contract;
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

		[owner, user] = await ethers.getSigners();

		operatorManager = await OperatorManager.connect(owner).deploy();
		await operatorManager.deployed();

		dragonNFT = await DragonNFT.connect(owner).deploy(maxLevel, xpToLevelUp, operatorManager.address);
		await dragonNFT.deployed();
	});

	it('should fail to mint a new dragon if caller is not an operator', async () => {
		const randomWords = [0, 0, 0, 0];
		await expect(dragonNFT.connect(user).mintNewDragon(user.getAddress(), randomWords)).to.be.revertedWith('DragonNFT : Not a valid operator');
	});

	it('should mint a new dragon successfully', async () => {
		const randomWords = [0, 0, 0, 0];

		const createTx = await dragonNFT.connect(owner).mintNewDragon(owner.getAddress(), randomWords);
		const createReceipt = await createTx.wait();
		const createEvents = createReceipt.events.find((e: any) => e.event === 'NewDragonBorn');
		const createTimestamp = (await ethers.provider.getBlock(createReceipt.blockNumber)).timestamp;

		expect(createEvents.args._gender).to.equal(0);
		expect(createEvents.args._rarity).to.equal(0);
		expect(createEvents.args._specie).to.equal(0);
		expect(createEvents.args._damage).to.equal(50);
		expect(createEvents.args._xpPerSec).to.equal(10);
		expect(createEvents.args._lastInteracted).to.equal(createTimestamp);

		const ownersBalance = await dragonNFT.balanceOf(owner.getAddress());
		const [ownersDragon] = await dragonNFT.getOwnedTokens(owner.getAddress());

		expect(ownersBalance).to.be.equal(1);
		expect(ownersDragon).to.be.equal(0);
	});

	it('should fail to transfer a dragon if caller is not the owner', async () => {
		const [ownersDragon] = await dragonNFT.getOwnedTokens(owner.getAddress());
		await expect(dragonNFT.connect(user).transferFrom(owner.getAddress(), user.getAddress(), ownersDragon)).to.be.revertedWith('ERC721: caller is not token owner or approved');
	});

	it('should transfer a dragon from owner to user', async () => {
		const [ownersDragon] = await dragonNFT.getOwnedTokens(owner.getAddress());
		await dragonNFT.connect(owner).transferFrom(owner.getAddress(), user.getAddress(), ownersDragon);

		const userBalance = await dragonNFT.balanceOf(user.getAddress());
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		expect(userBalance).to.be.equal(1);
		expect(userDragon).to.be.equal(0);
	});

	it('should retrieve correct dragon information after transfer', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const dragonInfo = await dragonNFT.getDragonInfo(userDragon);

		expect(dragonInfo.gender).to.equal(0);
		expect(dragonInfo.rarity).to.equal(0);
		expect(dragonInfo.specie).to.equal(0);
		expect(dragonInfo.level).to.be.equal(1);
		expect(dragonInfo.xp).to.be.equal(0);
		expect(dragonInfo.damage).to.equal(50);
		expect(dragonInfo.xpPerSec).to.equal(10);
	});

	it('should fail to add experience if caller is not the owner', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		await expect(dragonNFT.connect(owner).addExperience(userDragon)).to.be.revertedWith('DragonNFT : Caller is not the owner');
	});

	it('should correctly calculate and add experience for one hour', async () => {
		await time.increase(3600);

		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const dragon = await dragonNFT.getDragonInfo(userDragon);

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

		const transactionAddExp = await dragonNFT.connect(user).addExperience(userDragon);
		const receiptTxAddExp = await transactionAddExp.wait();
		const dragonExperienceGainedEvent = receiptTxAddExp.events.find((e: any) => e.event === 'DragonExperienceGained');

		expect(dragonExperienceGainedEvent.args._tokenId).to.be.equal(userDragon);
		expect(dragonExperienceGainedEvent.args._xp).to.be.equal(0);
		expect(dragonExperienceGainedEvent.args._level).to.be.equal(dragonLevel);
		// ? 103번째 줄에서 드래곤을 발행하고 다른 테스트가 순차적으로 진행됨에 따라 1~10초 정도 약간의 시간차가 발생할 수 있음 따라서 조건에 dragon.xpPerSec * 10을 추가함
		expect(dragonExperienceGainedEvent.args._xpToAdd).to.satisfy((num: number) => num >= xpForOneHour && num < xpForOneHour + dragon.xpPerSec * 10);
	});

	it('should fail to set experience required for next level if caller is not the owner', async () => {
		await expect(dragonNFT.connect(user).setXpToLevelUp(1, 1000)).to.be.revertedWith('Ownable: caller is not the owner');
	});

	it('should fail to set experience for an invalid level', async () => {
		const invalidLevel = maxLevel + 1;
		const xpRequired = 1000;

		await expect(dragonNFT.connect(owner).setXpToLevelUp(invalidLevel, xpRequired)).to.be.revertedWith('DragonNFT : Invalid level');
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
