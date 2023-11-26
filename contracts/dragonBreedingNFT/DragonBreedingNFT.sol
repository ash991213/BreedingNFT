// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../dragonRentalNFT/DragonRentalNFT.sol";

contract DragonBreedingNFT is DragonRentalNFT {
    // 드래곤 교배 수수료
    uint256 public constant BREEDING_FEE = 0.01 ether;

    // 드래곤 교배 대기시간
    uint256 public constant BREEDING_COOL_DOWN = 1 days;

    // 각 드래곤의 마지막 번식 시간을 추적하는 매핑
    mapping(uint256 => uint256) public lastBreedingTime;

    event DragonBred(uint256 _fatherTokenId, uint256 _matherTokenId, uint256 _childTokenId);
    event RentedDragonBred(uint256 indexed myDragonId, uint256 indexed rentedDragonId);

    constructor(uint8 _maxLevel, uint32[] memory _xpToLevelUp) DragonRentalNFT(_maxLevel, _xpToLevelUp) {
    }

    // 교배를 통한 드래곤 NFT 생성
    function breedDragons(address requster, uint256 parent1TokenId, uint256 parent2TokenId, uint256[] memory _randomWords) internal {
        Gender gender = determineGender(_randomWords[0]);
        Rarity rarity = determineBreedingRarity(parent1TokenId, parent2TokenId, _randomWords[1]);
        Species specie = determineSpecies(rarity, _randomWords[2]);
        uint64 damage = determineDamage(rarity, _randomWords[3]);
        uint32 xpPerSec = determineExperience(rarity);

        uint256 _tokenId = createDragon(requster, gender, rarity, specie, damage, xpPerSec);
        lastBreedingTime[parent1TokenId] = block.timestamp;
        lastBreedingTime[parent2TokenId] = block.timestamp;

        emit DragonBred(parent1TokenId, parent2TokenId, _tokenId);
        emit NewDragonBorn(_tokenId, gender, rarity, specie, damage, block.timestamp, xpPerSec);
    }

    // 드래곤 교배 가능 여부 확인
    function _isDragonOwnedOrRentedBySender(uint256 tokenId) internal view returns (bool) {
        DragonRental memory rental = getDragonRental(tokenId);
        if (rental.isRented) {
            bool isRentalActive = (block.timestamp - rental.startTime) <= rental.duration;
            return isRentalActive && (rental.renter == msg.sender);
        }
        return ownerOf(tokenId) == msg.sender;
    }

    // 대여자에게 수수료를 전송합니다.
    function _transferFeeToRenter(uint256 tokenId, address owner) internal {
        uint256 rentalFee = BREEDING_FEE * RENTAL_FEE_PERCENTAGE / 100;
        DragonRental memory dragonRentalInfo = getDragonRental(tokenId);
        payable(dragonRentalInfo.renter).transfer(rentalFee);
        payable(owner).transfer(BREEDING_FEE - rentalFee);
    }

    // 수수료를 분배하는 함수
    function distributeBreedingFee(uint256 parent1TokenId, uint256 parent2TokenId) internal {
        address owner1 = ownerOf(parent1TokenId);
        address owner2 = ownerOf(parent2TokenId);

        bool isParent1Rented = dragonRentals[parent1TokenId].isRented;
        bool isParent2Rented = dragonRentals[parent2TokenId].isRented;

        if (isParent1Rented && !isParent2Rented) {
            _transferFeeToRenter(parent1TokenId, owner1);
        } else if (isParent2Rented && !isParent1Rented) {
            _transferFeeToRenter(parent2TokenId, owner2);
        }
    }
}