// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DragonBreedLib {
    // 드래곤 교배 수수료
    uint256 public constant BREEDING_FEE = 0.01 ether;

    // 드래곤 교배 대기시간
    uint256 public constant BREEDING_COOL_DOWN = 1 days;
}