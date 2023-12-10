// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../library/DragonNFTLib.sol";

interface IDragonNFT {
    function mintNewDragon(address requester, uint256[] memory _randomWords) external;
    function createDragon(address _to, DragonNFTLib.Gender _gender, DragonNFTLib.Rarity _rarity, DragonNFTLib.Species _specie, uint16 _damage, uint8 _xpPerSec) external returns(uint256 tokenId);
    function addExperience(uint256 tokenId) external;
    function setXpToLevelUp(uint8 level, uint128 xpRequired) external;
    function getDragonInfo(uint256 tokenId) external view returns(DragonNFTLib.Dragon memory dragonInfo);
    function getRarityBasedExperience() external view returns (uint8[] memory);
    function getSpeciesCountPerRarity() external view returns (uint8[] memory);
    function getRarityBasedDamage() external view returns (uint16[] memory);
    function getOwnedTokens(address user) external view returns (uint256[] memory);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}