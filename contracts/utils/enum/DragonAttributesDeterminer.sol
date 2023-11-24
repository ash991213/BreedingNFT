// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../IDragonAttributesDeterminer.sol";

contract DragonAttributesDeterminer is IDragonAttributesDeterminer {
    // 드래곤 능력치 구조체
    struct Dragon {
        Gender gender;
        Rarity rarity;
        Species specie;
        uint8 level;
        uint32 xp;
        uint64 damage;
        uint256 lastInteracted;
        uint32 xpPerSec;
    }

    // TokenID에 따른 드래곤 정보를 저장하는 매핑
    mapping(uint256 => Dragon) public dragons;

    // 희귀도별 확률 가중치
    uint8[] public speciesCountPerRarity = [8, 5, 4, 3, 2, 1];

    // 희귀도별 데미지
    uint64[] public rarityBasedDamage = [50, 100, 170, 300, 450, 700];

    // 희귀도별 경험치 획득량
    uint32[] public rarityBasedExperience = [10, 12, 14, 16, 18, 20];

    // 랜덤 숫자를 기반으로 성별을 결정합니다.
    function determineGender(uint256 _randomWords) external pure returns(Gender gender) {
        return (_randomWords % 2 == 0) ? Gender.MALE : Gender.FEMALE;
    }

    // 랜덤 숫자를 기반으로 희귀도를 결정합니다.
    function determineRarity(uint256 _randomWords) external pure returns(Rarity rarity) {
        return (_randomWords % 2 == 0) ? Rarity.COMMON : Rarity.RARE;
    }

    // 부모 드래곤의 희귀도와 랜덤 숫자를 기반으로 자식 드래곤의 희귀도를 결정합니다.
    function determineBreedingRarity(uint256 parent1TokenId, uint256 parent2TokenId, uint256 randomValue) external view returns(Rarity rarity) {
        Dragon storage parent1 = dragons[parent1TokenId];
        Dragon storage parent2 = dragons[parent2TokenId];

        Rarity higherRarity = parent1.rarity < parent2.rarity ? parent2.rarity : parent1.rarity;
        Rarity lowerRarity = parent1.rarity < parent2.rarity ? parent1.rarity : parent2.rarity;

        // 10% 확률로 높은 등급보다 1단계 높은 등급의 희귀도 반환
        uint256 rand = randomValue % 100;
        if(rand < 10){
            return higherRarity < Rarity.MYTHICAL ? Rarity(uint(higherRarity) + 1) : higherRarity;
        } else if (rand < 70) {
            return higherRarity;
        } else {
            return lowerRarity; 
        }
    }

    // 희귀도와 랜덤 숫자를 기반으로 드래곤 종류를 결정합니다.
    function determineSpecies(Rarity rarity, uint256 randomValue) external view returns (Species specie) {
        uint256 speciesRarityOffset = _getRarityOffset(uint256(rarity));
        return Species(speciesRarityOffset + (randomValue % speciesCountPerRarity[uint256(rarity)]));
    }

    // 특정 희귀도의 시작 Species 인덱스 구합니다.
    function _getRarityOffset(uint256 _rarity) internal view returns (uint256) {
        uint256 offset = 0;
        for(uint256 i = 0; i < _rarity; i++) {
            offset += speciesCountPerRarity[i];
        }
        return offset;
    }

    // 희귀도와 랜덤 숫자를 기반으로 데미지를 결정합니다.
    function determineDamage(Rarity rarity, uint256 randomValue) external view returns(uint64) {
        uint64 damage;

        if (rarity == Rarity.COMMON || rarity == Rarity.RARE) {
            damage = uint64(rarityBasedDamage[uint(rarity)] + (randomValue % 51));
        } else if (rarity == Rarity.EPIC || rarity == Rarity.UNIQUE) {
            damage = uint64(rarityBasedDamage[uint(rarity)] + (randomValue % 151));
        } else {
            damage = uint64(rarityBasedDamage[uint(rarity)] + (randomValue % 301));
        }

        return damage;
    }

    // 희귀도를 기반으로 획득 경험치를 결정합니다.
    function determineExperience(Rarity rarity) external view returns(uint32 experience) {
        return rarityBasedExperience[uint(rarity)];
    }
}