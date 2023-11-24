// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DragonAttributesEnum.sol";

interface IDragonAttributesDeterminer {
    function determineGender(uint256 _randomWords) external pure returns(Gender gender);
    function determineRarity(uint256 _randomWords) external pure returns(Rarity rarity);
    function determineBreedingRarity(uint256 parent1TokenId, uint256 parent2TokenId, uint256 randomValue) external view returns(Rarity rarity);
    function determineSpecies(Rarity rarity, uint256 randomValue) external view returns (Species specie);
    function getRarityOffset(uint256 _rarity) external view returns (uint256);
    function determineDamage(Rarity rarity, uint256 randomValue) external view returns(uint64);
    function determineExperience(Rarity rarity) external view returns(uint32 experience);
}