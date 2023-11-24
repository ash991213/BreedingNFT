// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum Gender {
    MALE,
    FEMALE
}

enum Rarity {
    COMMON,
    RARE,
    EPIC,
    UNIQUE,
    LEGENDARY,
    MYTHICAL
}

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