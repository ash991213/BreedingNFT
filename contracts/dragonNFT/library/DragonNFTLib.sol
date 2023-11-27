// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DragonNFTLib {
    // 성별
    enum Gender {
        MALE,
        FEMALE
    }

    // 희귀도
    enum Rarity {
        COMMON,
        RARE,
        EPIC,
        UNIQUE,
        LEGENDARY,
        MYTHICAL
    }

    // 희귀도별 종류
    enum Species {
        // Common - 8
        WIND_DRAGON,
        ROCK_DRAGON,
        THUNDER_DRAGON,
        FOREST_DRAGON,
        WATER_DRAGON,
        FIRE_DRAGON,
        ICE_DRAGON,
        POISON_DRAGON,
        
        // Rare - 5
        VORTEX_DRAGON,
        EARTHQUAKE_DRAGON,
        SAND_DRAGON,
        MAGMA_DRAGON,
        SWAMP_DRAGON,
        
        // EPIC - 4
        LIGHT_DRAGON,
        DARKNESS_DRAGON,
        GRAVITY_DRAGON,
        METEOR_DRAGON,

        // UNIQUE - 3
        BONE_DRAGON,
        ORE_DRAGON,
        ENERGY_DRAGON,

        // LEGENDARY - 2
        SPIRIT_DRAGON,
        STAR_DRAGON,

        // MYTHICAL - 1
        TIME_DRAGON
    }

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

    // 랜덤 숫자를 기반으로 성별을 결정합니다.
    function determineGender(uint256 randomValue) internal pure returns (Gender) {
        return (randomValue % 2 == 0) ? Gender.MALE : Gender.FEMALE;
    }

    // 랜덤 숫자를 기반으로 희귀도를 결정합니다.
    function determineRarity(uint256 _randomWords) internal pure returns(Rarity rarity) {
        return (_randomWords % 2 == 0) ? Rarity.COMMON : Rarity.RARE;
    }

    // 희귀도와 랜덤 숫자를 기반으로 드래곤 종류를 결정합니다.
    function determineSpecies(uint256 _randomValue, Rarity _rarity, uint8[] memory _speciesCountPerRarity) internal pure returns (Species specie) {
        uint256 speciesRarityOffset = _getRarityOffset(uint256(_rarity), _speciesCountPerRarity);
        return Species(speciesRarityOffset + (_randomValue % _speciesCountPerRarity[uint256(_rarity)]));
    }

    // 특정 희귀도의 시작 Species 인덱스 구합니다.
    function _getRarityOffset(uint256 _rarity, uint8[] memory _speciesCountPerRarity) internal pure returns (uint256) {
        uint256 offset = 0;
        for(uint256 i = 0; i < _rarity; i++) {
            offset += _speciesCountPerRarity[i];
        }
        return offset;
    }

    // 희귀도와 랜덤 숫자를 기반으로 데미지를 결정합니다.
    function determineDamage(uint256 _randomValue, Rarity _rarity, uint64[] memory _rarityBasedDamage) internal pure returns(uint64) {
        uint64 damage;

        if (_rarity == Rarity.COMMON || _rarity == Rarity.RARE) {
            damage = uint64(_rarityBasedDamage[uint(_rarity)] + (_randomValue % 51));
        } else if (_rarity == Rarity.EPIC || _rarity == Rarity.UNIQUE) {
            damage = uint64(_rarityBasedDamage[uint(_rarity)] + (_randomValue % 151));
        } else {
            damage = uint64(_rarityBasedDamage[uint(_rarity)] + (_randomValue % 301));
        }

        return damage;
    }

    // 희귀도를 기반으로 획득 경험치를 결정합니다.
    function determineExperience(Rarity _rarity, uint32[] memory _rarityBasedExperience) internal pure returns(uint32 experience) {
        return _rarityBasedExperience[uint(_rarity)];
    }
}
