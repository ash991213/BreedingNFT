const { expect } = require('chai');
const { ethers } = require('hardhat');

const errException = async (promise: Promise<any>): Promise<any> => {
	try {
		await promise;
	} catch (error: any) {
		return error;
	}
	throw new Error('Expected throw not received');
};

describe('OperatorManager Test', () => {
	let operatorManager;
	let owner;
	let addr1;
	let addr2;

	beforeEach(async () => {
		const OperatorManager = await ethers.getContractFactory('OperatorManager');
		[owner, addr1, addr2] = await ethers.getSigners();

		operatorManager = await OperatorManager.connect(owner).deploy();
		await operatorManager.deployed();
	});

	describe('Deployment', () => {
		it('Should set the right owner', async () => {
			expect(await operatorManager.owner()).to.equal(owner.address);
		});

		it('Owner should be an operator', async () => {
			expect(await operatorManager.isOperator(owner.address)).to.be.true;
		});
	});

	describe('Manage Operators', () => {
		it('Should add an operator', async () => {
			await operatorManager.connect(owner).addOperator(addr1.address);
			expect(await operatorManager.isOperator(addr1.address)).to.be.true;
		});

		it('Should remove an operator', async () => {
			await operatorManager.connect(owner).addOperator(addr1.address);
			await operatorManager.connect(owner).removeOperator(addr1.address);
			expect(await operatorManager.isOperator(addr1.address)).to.be.false;
		});

		it('Only owner can add operators', async () => {
			await errException(operatorManager.connect(addr1).addOperator(addr2.address));
		});

		it('Only owner can remove operators', async () => {
			await operatorManager.addOperator(addr1.address);
			await errException(operatorManager.connect(addr1).removeOperator(addr1.address));
		});
	});
});
