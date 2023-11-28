// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// * libraries
import "./library/DragonBreedLib.sol";
import "../dragonNFT/library/DragonNFTLib.sol";
import "../dragonRental/library/DragonRentalLib.sol";

// * interfaces
import "../dragonNFT/interface/IDragonNFT.sol";
import "../dragonRental/interface/IDragonRental.sol";
import "../operator/interface/IOperator.sol";

contract DragonBreed {
    IDragonNFT private dragonNft;
    IDragonRental private dragonRental;
    IOperator private operator;

    using DragonNFTLib for uint256;

    // 드래곤의 마지막 교배 시간을 추적하는 매핑
    mapping(uint256 => uint256) public lastBreedingTime;

    // 희귀도별 경험치 획득량, 확률 가중치, 데미지
    uint32[] public rarityBasedExperience;
    uint8[] public speciesCountPerRarity;
    uint64[] public rarityBasedDamage;

    // 교배 관련 이벤트
    event DragonBred(uint256 _fatherTokenId, uint256 _matherTokenId, uint256 _childTokenId);

    modifier onlyOperator() {
        require(operator.isOperator(msg.sender), "DragonBreedingNFT : msg.sender is no a valid operator");
        _;
    }

    constructor(address _dragonNft, address _dragonRental, address _operator) {
        dragonNft = IDragonNFT(_dragonNft);
        dragonRental = IDragonRental(_dragonRental);
        operator = IOperator(_operator);
        rarityBasedExperience = dragonNft.getRarityBasedExperience();
        speciesCountPerRarity = dragonNft.getSpeciesCountPerRarity();
        rarityBasedDamage = dragonNft.getRarityBasedDamage();
    }

    // 드래곤을 교배하여 새로운 드래곤을 생성합니다.
    function breedDragons(address requester, uint256 parent1TokenId, uint256 parent2TokenId, uint256[] memory _randomWords) external onlyOperator {
        DragonNFTLib.Gender gender = _randomWords[0].determineGender();
        DragonNFTLib.Rarity rarity = determineBreedingRarity(parent1TokenId, parent2TokenId, _randomWords[1]);
        DragonNFTLib.Species species = _randomWords[2].determineSpecies(rarity, speciesCountPerRarity);
        uint64 damage = _randomWords[3].determineDamage(rarity, rarityBasedDamage);
        uint32 xpPerSec = DragonNFTLib.determineExperience(rarity, rarityBasedExperience);

        uint256 tokenId = dragonNft.createDragon(requester, gender, rarity, species, damage, xpPerSec);
        updateLastBreedingTime(parent1TokenId, parent2TokenId);

        dragonRental.cancelRental(tokenId);

        emit DragonBred(parent1TokenId, parent2TokenId, tokenId);
    }

    // 두 부모 드래곤의 희귀도를 비교하여 자식 드래곤의 희귀도를 결정합니다.
    function determineBreedingRarity(uint256 parent1TokenId, uint256 parent2TokenId, uint256 randomValue) internal view returns(DragonNFTLib.Rarity) {
        DragonNFTLib.Rarity higherRarity;
        DragonNFTLib.Rarity lowerRarity;
        (higherRarity, lowerRarity) = _compareRarities(parent1TokenId, parent2TokenId);

        uint256 rand = randomValue % 100;
        if (rand < 10) {
            return higherRarity < DragonNFTLib.Rarity.MYTHICAL ? DragonNFTLib.Rarity(uint(higherRarity) + 1) : higherRarity;
        } else if (rand < 70) {
            return higherRarity;
        } else {
            return lowerRarity;
        }
    }

    // 두 드래곤의 희귀도를 비교합니다.
    function _compareRarities(uint256 parent1TokenId, uint256 parent2TokenId) internal view returns (DragonNFTLib.Rarity, DragonNFTLib.Rarity) {
        DragonNFTLib.Rarity rarity1 = dragonNft.getDragonInfo(parent1TokenId).rarity;
        DragonNFTLib.Rarity rarity2 = dragonNft.getDragonInfo(parent2TokenId).rarity;
        return (rarity1 < rarity2 ? rarity2 : rarity1, rarity1 < rarity2 ? rarity1 : rarity2);
    }

    // 드래곤 교배에 대한 수수료를 분배합니다.
    function distributeBreedingFee(uint256 parent1TokenId, uint256 parent2TokenId) external onlyOperator {
        _transferFee(parent1TokenId, parent2TokenId);
    }

    // 두 부모 드래곤에 대한 수수료를 계산하고 이를 각 부모 드래곤의 소유자에게 전송합니다.
    function _transferFee(uint256 parent1TokenId, uint256 parent2TokenId) internal {
        address owner1 = dragonNft.ownerOf(parent1TokenId);
        address owner2 = dragonNft.ownerOf(parent2TokenId);

        (bool isParent1Rented, uint256 rentalFee1) = _calculateRentalFee(parent1TokenId);
        (bool isParent2Rented, uint256 rentalFee2) = _calculateRentalFee(parent2TokenId);

        if (isParent1Rented && !isParent2Rented) {
            _distributeFee(owner1, rentalFee1);
        } else if (isParent2Rented && !isParent1Rented) {
            _distributeFee(owner2, rentalFee2);
        }
    }

    // 주어진 드래곤의 대여 수수료를 계산합니다.
    function _calculateRentalFee(uint256 tokenId) internal view returns (bool isRented, uint256 rentalFee) {
        DragonRentalLib.DragonRental memory rentalInfo = dragonRental.getDragonRental(tokenId);
        if (rentalInfo.isRented && dragonRental.isRentalActive(tokenId)) {
            rentalFee = DragonBreedLib.BREEDING_FEE * DragonRentalLib.RENTAL_FEE_PERCENTAGE / 100;
            return (true, rentalFee);
        }
        return (false, 0);
    }

    // 주어진 주소로 수수료를 전송합니다.
    function _distributeFee(address owner, uint256 rentalFee) internal {
        payable(owner).transfer(DragonBreedLib.BREEDING_FEE - rentalFee);
    }

    // 마지막 교배 시간을 업데이트합니다.
    function updateLastBreedingTime(uint256 parent1TokenId, uint256 parent2TokenId) internal {
        lastBreedingTime[parent1TokenId] = block.timestamp;
        lastBreedingTime[parent2TokenId] = block.timestamp;
    }

    // 드래곤의 마지막 교배 시간을 반환합니다.
    function getLastBreedingTime(uint256 tokenId) public view returns(uint256) {
        return lastBreedingTime[tokenId];
    }
}