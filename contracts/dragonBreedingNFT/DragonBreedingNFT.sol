// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../dragonRentalNFT/DragonRentalNFT.sol";

import "../chainlink/IVRFv2Consumer.sol";
import "../utils/DragonAttributesDeterminer.sol";

contract DragonBreedingNFT {
    DragonRentalNFT private dragonRentalNFT;
    IVRFv2Consumer private vrfConsumer;
    DragonAttributesDeterminer private dragonAttributesDeterminer;

    // 드래곤 교배 수수료
    uint256 public constant BREEDING_FEE = 0.01 ether;

    // 드래곤 교배 대기시간
    uint256 public constant BREEDING_COOL_DOWN = 1 days;

    // 각 드래곤의 마지막 번식 시간을 추적하는 매핑
    mapping(uint256 => uint256) public lastBreedingTime;

    event DragonBred(uint256 _fatherTokenId, uint256 _matherTokenId, uint256 _childTokenId);
    event RentedDragonBred(uint256 indexed myDragonId, uint256 indexed rentedDragonId);

    constructor(address _dragonAttributesDeterminer, address _dragonRentalNFT, address _vrfConsumer) {
        dragonAttributesDeterminer = DragonAttributesDeterminer(dragonAttributesDeterminer);
        dragonRentalNFT = DragonRentalNFT(_dragonRentalNFT);
        vrfConsumer = IVRFv2Consumer(_vrfConsumer);
    }

    // 드래곤 교배 함수
    function breedDragons(uint256 parent1TokenId, uint256 parent2TokenId) external payable returns (uint256 requestId) {
        require(msg.value == BREEDING_FEE, "DragonBreedingNFT : Incorrect ETH amount");
        require(dragonMintingNFT.ownerOf(parent1TokenId) != address(0) && dragonMintingNFT.ownerOf(parent2TokenId) != address(0), "DragonBreedingNFT : Dragon does not exist");
        require(_isDragonOwnedOrRentedBySender(parent1TokenId) || _isDragonOwnedOrRentedBySender(parent2TokenId), "At least one dragon must be owned or rented by the caller.");

        DragonMintingNFT.Gender parent1Gender = dragonMintingNFT.getDragonGender(parent1TokenId);
        DragonMintingNFT.Gender parent2Gender = dragonMintingNFT.getDragonGender(parent2TokenId);

        require(parent1Gender != parent2Gender, "DragonBreedingNFT : Dragons must be of different genders");
        require(block.timestamp >= lastBreedingTime[parent1TokenId] + BREEDING_COOL_DOWN && block.timestamp >= lastBreedingTime[parent2TokenId] + BREEDING_COOL_DOWN, "DragonBreedingNFT : Breeding cooldown active");
        
        return vrfConsumer.requestRandomWordsForPurpose(RequestPurpose.BREEDING, parent1TokenId, parent2TokenId);
    }

    // 교배를 통한 드래곤 NFT 생성
    function _breedDragons(address requster, uint256 parent1TokenId, uint256 parent2TokenId, uint256[] memory _randomWords) internal {
        DragonMintingNFT.Gender gender = dragonMintingNFT.determineGender(_randomWords[0]);
        DragonMintingNFT.Rarity rarity = dragonMintingNFT.determineBreedingRarity(parent1TokenId, parent2TokenId, _randomWords[1]);
        DragonMintingNFT.Species specie = dragonMintingNFT.determineSpecies(rarity, _randomWords[2]);
        uint64 damage = dragonMintingNFT.determineDamage(rarity, _randomWords[3]);
        uint32 xpPerSec = dragonMintingNFT.determineExperience(rarity);

        uint256 _tokenId = dragonMintingNFT.createDragon(requster, gender, rarity, specie, damage, xpPerSec);
        lastBreedingTime[parent1TokenId] = block.timestamp;
        lastBreedingTime[parent2TokenId] = block.timestamp;

        emit DragonBred(parent1TokenId, parent2TokenId, _tokenId);
        emit DragonMintingNFT.NewDragonBorn(_tokenId, gender, rarity, specie, damage, block.timestamp, xpPerSec);
    }

    // 드래곤 교배 가능 여부 확인
    function _isDragonOwnedOrRentedBySender(uint256 tokenId) internal view returns (bool) {
        DragonRentalNFT.DragonRental memory rental = dragonRentalNFT.dragonRentals[tokenId];
        if (rental.isRented) {
            bool isRentalActive = (block.timestamp - rental.startTime) <= rental.duration;
            return isRentalActive && (rental.renter == msg.sender);
        }
        return dragonMintingNFT.ownerOf(tokenId) == msg.sender;
    }

    // 대여자에게 수수료를 전송합니다.
    function _transferFeeToRenter(uint256 tokenId, address owner) internal {
        uint256 rentalFee = BREEDING_FEE * DragonRentalNFT.RENTAL_FEE_PERCENTAGE / 100;
        payable(dragonRentalNFT.dragonRentals[tokenId].renter).transfer(rentalFee);
        payable(owner).transfer(BREEDING_FEE - rentalFee);
    }

    // 수수료를 분배하는 함수
    function _distributeBreedingFee(uint256 parent1TokenId, uint256 parent2TokenId) internal {
        address owner1 = dragonMintingNFT.ownerOf(parent1TokenId);
        address owner2 = dragonMintingNFT.ownerOf(parent2TokenId);

        bool isParent1Rented = dragonRentalNFT.dragonRentals[parent1TokenId].isRented;
        bool isParent2Rented = dragonRentalNFT.dragonRentals[parent2TokenId].isRented;

        if (isParent1Rented && !isParent2Rented) {
            _transferFeeToRenter(parent1TokenId, owner1);
        } else if (isParent2Rented && !isParent1Rented) {
            _transferFeeToRenter(parent2TokenId, owner2);
        }
    }
}