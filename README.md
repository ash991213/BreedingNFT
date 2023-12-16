## Introduction

The Dragon Blockchain Ecosystem is a suite of smart contracts on the Ethereum blockchain, designed for creating, breeding, renting, and interacting with unique Dragon NFTs. This ecosystem utilizes Chainlink VRF for randomization and offers an immersive experience in digital dragon rearing and breeding.

## Contracts Overview

DragonNFT: Manages the creation and attributes of Dragon NFTs.

DragonBreed: Facilitates the breeding of dragons to create new NFTs with unique attributes.

DragonRental: Allows users to rent their Dragon NFTs to others.

VRFv2Consumer: Integrates Chainlink VRF for random number generation, crucial for the minting and breeding processes.

## Features

Minting of Dragon NFTs: Create unique dragon NFTs with randomly assigned attributes.

Breeding Mechanism: Breed two dragons to produce a new dragon with combined traits.

Rental System: Rent out dragons for others to use in breeding or other activities.

Chainlink VRF Integration: Ensures fair and unpredictable outcomes in minting and breeding.

Reward Distribution: Participants in the ecosystem (such as breeders) can receive rewards in the form of Ethereum.

## Requirements

Solidity ^0.8.20: Smart contract programming language.

Ethereum Blockchain: For contract deployment and execution.

Chainlink VRF: For verifiable randomness in the minting and breeding process.

OpenZeppelin Contracts: For secure, standard contract implementations, especially for ERC721 tokens.

## Usage

Deploy all contracts on an Ethereum network. you can use scripts/deploy.ts

Initialize DragonNFT, DragonBreed, DragonRental, and VRFv2Consumer with appropriate parameters and addresses.

### Minting Dragons

Call mintNewDragon in VRFv2Consumer to create a new Dragon NFT with random attributes.

Pay the specified minting fee in ETH.

### Breeding Dragons

Use breedDragons in DragonBreed to breed two dragons.

Ensure the necessary conditions (like cooldown period and ownership) are met.

### Renting Dragons

Dragons can be rented out for breeding or other purposes through DragonRental.

### Managing Rewards

Rewards are distributed to dragon owners based on participation in breeding or rental activities.

Withdraw rewards using the withdraw function in VRFv2Consumer.

## Testing

Integration Tests: Ensure that the contracts work together as expected.

Simulation Tests: Mimic user interactions and breeding scenarios to test the overall workflow.
