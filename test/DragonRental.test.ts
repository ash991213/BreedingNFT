import { ethers } from 'hardhat';
import { Contract, Signer } from 'ethers';
import { expect } from 'chai';

describe('DragonRental Test', async () => {
	let operatorManager: Contract;
	let dragonNFT: Contract;
	let dragonRental: Contract;
	let owner: Signer;
	let user: Signer;
	let user2: Signer;

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

		[owner, user, user2] = await ethers.getSigners();

		operatorManager = await OperatorManager.connect(owner).deploy();
		await operatorManager.deployed();

		dragonNFT = await DragonNFT.connect(owner).deploy(maxLevel, xpToLevelUp, operatorManager.address);
		await dragonNFT.deployed();

		const randomWords = [0, 0, 0, 0];
		const createTx = await dragonNFT.connect(owner).mintNewDragon(user.getAddress(), randomWords);
		await createTx.wait();

		dragonRental = await DragonRental.connect(owner).deploy(operatorManager.address, dragonNFT.address);
		await dragonRental.deployed();
	});

	it('should fail to rent a dragon if caller is not the owner', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		await expect(dragonRental.connect(owner).rentDragon(userDragon)).to.be.revertedWith('DragonRental : Not owner.');
	});

	it('should correctly mark a dragon as rented upon successful rental', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const transactionRentDragon = await dragonRental.connect(user).rentDragon(userDragon);
		await transactionRentDragon.wait();
		const transactionGetDragonRental = await dragonRental.getDragonRental(userDragon);

		expect(transactionGetDragonRental.isRented).to.be.equal(true);
		expect(transactionGetDragonRental.renter).to.be.equal(await user.getAddress());
		expect(transactionGetDragonRental.duration - transactionGetDragonRental.startTime).to.be.equal(172800);
	});

	it('should fail to rent a dragon if it is already rented', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		await expect(dragonRental.connect(user).rentDragon(userDragon)).to.be.revertedWith('DragonRental : Already rented.');
	});

	it('should confirm that a rental is active for a dragon', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const isRentalActive = await dragonRental.connect(user).isRentalActive(userDragon);
		expect(isRentalActive).to.be.equal(true);
	});

	it('should retrieve the list of currently rented dragons', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const [rentedDragon] = await dragonRental.getCurrentlyRentedDragons();
		expect(rentedDragon).to.be.equal(userDragon);
	});

	it('should fail to cancel rental if caller is neither renter nor operator', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		await expect(dragonRental.connect(user2).cancelRental(userDragon)).to.be.revertedWith('DragonRental: Not renter or Operator.');
	});

	it('should cancel a dragon rental and emit the appropriate event', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const transactionCancelRental = await dragonRental.connect(user).cancelRental(userDragon);
		const receiptCancelRental = await transactionCancelRental.wait();
		const DragonRentalCancelledEvent = receiptCancelRental.events.find((e: any) => e.event === 'DragonRentalCancelled');
		expect(DragonRentalCancelledEvent.args.tokenId).to.be.equal(userDragon);
		expect(DragonRentalCancelledEvent.args.renter).to.be.equal(await user.getAddress());
	});

	it('should fail to cancel rental if rental is not active', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		await expect(dragonRental.connect(user).cancelRental(userDragon)).to.be.revertedWith('DragonRental: Not renter or Operator.');
		await expect(dragonRental.connect(owner).cancelRental(userDragon)).to.be.revertedWith('DragonRental: Rental not active.');
	});

	it('should return invalid rental information for non-rented dragon', async () => {
		const [userDragon] = await dragonNFT.getOwnedTokens(user.getAddress());
		const rentalInfo = await dragonRental.getDragonRental(userDragon);

		expect(rentalInfo.isRented).to.be.false;
	});
});
