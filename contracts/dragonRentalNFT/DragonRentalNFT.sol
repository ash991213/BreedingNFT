// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../dragonMintingNFT/DragonMintingNFT.sol";

contract DragonRentalNFT is DragonMintingNFT {
    // 드래곤 대여 구조체
    struct DragonRental {
        bool isRented;
        uint256 startTime;
        uint256 duration;
        address renter;
    }

    // 드래곤 대여 정보를 저장하는 매핑
    mapping(uint256 => DragonRental) public dragonRentals;

    // 드래곤 대여 수수료 비율
    uint256 public constant RENTAL_FEE_PERCENTAGE = 10;

    event DragonRented(uint256 indexed tokenId, address indexed renter, uint256 duration);

    constructor(uint8 _maxLevel, uint32[] memory _xpToLevelUp) DragonMintingNFT(_maxLevel, _xpToLevelUp) {
    }

    // 드래곤 대여 함수
    function rentDragon(uint256 tokenId, uint256 duration) external {
        require(IERC721(address(this)).ownerOf(tokenId) == msg.sender, "DragonRental : Only the owner can rent out a dragon.");
        require(!dragonRentals[tokenId].isRented, "DragonRental : Dragon is already rented.");

        dragonRentals[tokenId] = DragonRental({
            isRented : true,
            startTime : block.timestamp,
            duration : duration,
            renter : msg.sender
        });

        emit DragonRented(tokenId, msg.sender, duration);
    }

    function getDragonRental(uint256 tokenId) public view returns(DragonRental memory dragonRental) {
        return dragonRentals[tokenId];
    }
}

