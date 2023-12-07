// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDragonBreed {
    function breedDragons(address requster, uint256 parent1TokenId, uint256 parent2TokenId, uint256[] memory _randomWords) external;
    function distributeBreedingFee(uint256 parent1TokenId, uint256 parent2TokenId) external returns(address owner, uint256 rentalFee);
    function getLastBreedingTime(uint256 tokenId) external view returns(uint256 dragonLastBreedingTime);
}