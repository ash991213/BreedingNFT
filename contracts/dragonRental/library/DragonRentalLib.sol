// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DragonRentalLib {
    // 드래곤 대여 수수료 비율
    uint256 public constant RENTAL_FEE_PERCENTAGE = 10;

    // 드래곤 대여 구조체
    struct DragonRental {
        bool isRented;
        uint256 startTime;
        uint256 duration;
        address renter;
    }
}