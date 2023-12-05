// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../library/DragonRentalLib.sol";

interface IDragonRental {
    function rentDragon(uint256 tokenId, uint256 duration) external;
    function cancelRental(uint256 tokenId) external;
    function isRentalActive(uint256 tokenId) external view returns (bool);
    function getDragonRental(uint256 tokenId) external view returns(DragonRentalLib.DragonRental memory dragonRental);
}