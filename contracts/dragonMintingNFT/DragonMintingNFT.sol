// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Tokens
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Utils
import "@openzeppelin/contracts/utils/Counters.sol";

// Access
import "@openzeppelin/contracts/access/Ownable.sol";

// interface
import "../chainlink/IVRFv2Consumer.sol";

contract DragonMintingNFT is ERC721, Ownable{
    IVRFv2Consumer private vrfConsumer;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

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

    // 최고 레벨
    uint8 MAX_LEVEL;

    // 레벨업 하는데 필요한 경험치 배열
    uint32[] public xpToLevelUp;

    // 희귀도별 확률 가중치
    uint8[] public speciesCountPerRarity = [8, 5, 4, 3, 2, 1];

    // 희귀도별 데미지
    uint64[] public rarityBasedDamage = [50, 100, 170, 300, 450, 700];

    // 희귀도별 경험치 획득량
    uint32[] public rarityBasedExperience = [10, 12, 14, 16, 18, 20];

    // 드래곤 발행 수수료
    uint256 public constant NFT_MINT_FEE = 0.01 ether;

    event NewDragonBorn(uint256 _tokenId, Gender _gender, Rarity _rarity, Species _specie, uint64 _damage, uint256 _lastInteracted, uint32 _xpPerSec);
    event DragonExperienceGained(uint256 _tokenId, uint8 _level, uint32 _xp, uint32 _xpToAdd);
    event DragonLevelUp(uint256 _tokenId, uint8 _level, uint32 _xp, uint64 _damage);
    event DragonLevelXPAdjusted(uint8 level, uint32 previousXP, uint32 newXP);
    event DragonMaxLevelReached(uint256 _tokenId, Gender _gender, Rarity _rarity, Species _specie, uint64 _damage, uint8 _level);

    // _xpToLevelUp 비선형적으로 계산해서 인자값으로 받습니다.
    constructor(uint8 _maxLevel, uint32[] memory _xpToLevelUp, address _vrfConsumer) ERC721("Dragon Rearing","DR") {
        require(_maxLevel == _xpToLevelUp.length, "DragonBreedingNFT : Max level and xp array length must match");
        MAX_LEVEL = _maxLevel;
        xpToLevelUp = _xpToLevelUp;
        vrfConsumer = IVRFv2Consumer(_vrfConsumer);
    }

    // 신규 드래곤 생성 함수
    function mintNewDragon() external payable returns (uint256 requestId) {
        require(msg.value == NFT_MINT_FEE, "DragonBreedingNFT : Incorrect ETH amount");
        return vrfConsumer.requestRandomWordsForPurpose(RequestPurpose.MINTING, 0, 0);
    }

    // 신규 드래곤 NFT 생성
    function _mintNewDragon(address requester, uint256[] memory _randomWords) internal {
        Gender gender = determineGender(_randomWords[0]);
        Rarity rarity = determineRarity(_randomWords[1]);
        Species specie = determineSpecies(rarity, _randomWords[2]);
        uint64 damage = determineDamage(rarity, _randomWords[3]);
        uint32 xpPerSec = determineExperience(rarity);

        uint256 _tokenId = createDragon(requester, gender, rarity, specie, damage, xpPerSec);
        emit NewDragonBorn(_tokenId, gender, rarity, specie, damage, block.timestamp, xpPerSec);
    }
    
    // 랜덤 숫자를 기반으로 성별을 결정합니다.
    function determineGender(uint256 _randomWords) public pure returns(Gender gender) {
        return (_randomWords % 2 == 0) ? Gender.MALE : Gender.FEMALE;
    }

    // 랜덤 숫자를 기반으로 희귀도를 결정합니다.
    function determineRarity(uint256 _randomWords) public pure returns(Rarity rarity) {
        return (_randomWords % 2 == 0) ? Rarity.COMMON : Rarity.RARE;
    }

    // 부모 드래곤의 희귀도와 랜덤 숫자를 기반으로 자식 드래곤의 희귀도를 결정합니다.
    function determineBreedingRarity(uint256 parent1TokenId, uint256 parent2TokenId, uint256 randomValue) public view returns(Rarity rarity) {
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
    function determineSpecies(Rarity rarity, uint256 randomValue) public view returns (Species specie) {
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
    function determineDamage(Rarity rarity, uint256 randomValue) public view returns(uint64) {
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
    function determineExperience(Rarity rarity) public view returns(uint32 experience) {
        return rarityBasedExperience[uint(rarity)];
    }

    // 드래곤 NFT를 생성합니다.
    function createDragon(address _to, Gender _gender, Rarity _rarity, Species _specie, uint64 _damage, uint32 _xpPerSec) public returns(uint256 tokenId) {
        uint256 _tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        dragons[_tokenId] = Dragon({
            gender : _gender,
            rarity : _rarity,
            specie : _specie,
            level : 1,
            xp : 0,
            damage : _damage,
            lastInteracted : block.timestamp, 
            xpPerSec : _xpPerSec
        });

        _safeMint(_to, _tokenId);
        return tokenId;
    }

    // 현재까지 축적된 드래곤의 경험치를 증가시킵니다.
    function addExperience(uint256 tokenId) external {
        // NFT의 소유자인지 확인합니다.
        require(ownerOf(tokenId) != msg.sender, "DragonBreedingNFT : Caller is not the owner of the NFT");
        
        Dragon storage dragon = dragons[tokenId];
        
        // 드래곤이 이미 최고 레벨에 도달했는지 확인합니다.
        require(dragon.level < MAX_LEVEL, "DragonBreedingNFT : Dragon at max level");

        uint256 currentTime = block.timestamp;
        uint256 secondsPassed = currentTime - dragon.lastInteracted;

        // 경험치를 추가할 시간이 지났는지 확인합니다.
        require(secondsPassed > 0, "DragonBreedingNFT : No time passed since last interaction");

        uint32 xpToAdd = uint32(secondsPassed * dragon.xpPerSec);
        uint32 xpRequiredForNextLevel = xpToLevelUp[dragon.level - 1];

        // 레벨업을 위한 경험치가 충분한지 확인합니다.
        if (dragon.xp + xpToAdd >= xpRequiredForNextLevel) {
            uint8 levelsGained = 0;
            uint32 xpRemaining = dragon.xp + xpToAdd;

            // 드래곤의 경험치가 다음 레벨업에 필요한 경험치 이상인지를 반복적으로 확인하고, 필요한 경우 드래곤의 레벨을 올립니다.
            while (xpRemaining >= xpRequiredForNextLevel && dragon.level + levelsGained < MAX_LEVEL) {
                xpRemaining -= xpRequiredForNextLevel;
                levelsGained++;
                if (dragon.level + levelsGained < MAX_LEVEL) {
                    xpRequiredForNextLevel = xpToLevelUp[dragon.level + levelsGained - 1];
                }
            }

            dragon.level += levelsGained;
            dragon.xp = xpRemaining;
            dragon.damage += dragon.damage * levelsGained / 5;
            dragon.lastInteracted = currentTime;

            // 레벨업 이벤트 발생
            emit DragonLevelUp(tokenId, dragon.level, dragon.xp, dragon.damage);
        } else {
            dragon.xp += xpToAdd;
            dragon.lastInteracted = currentTime;
        }

        emit DragonExperienceGained(tokenId, dragon.level, dragon.xp, xpToAdd);
    }

    // 레벨에 따라 필요한 XP를 재설정합니다.
    function setXpToLevelUp(uint8 level, uint32 xpRequired) external onlyOwner {
        require(level < MAX_LEVEL, "DragonBreedingNFT: Invalid level");
        uint32 previousXP = xpToLevelUp[level];
        xpToLevelUp[level] = xpRequired;
        emit DragonLevelXPAdjusted(level, previousXP, xpRequired);
    }

    function getDragonGender(uint256 tokenId) public view returns (Gender gender) {
        Dragon storage dragon = dragons[tokenId];
        return dragon.gender;
    }

    // 스마트 컨트랙트에 저장된 이더리움을 스마트 컨트랙트 소유자에게 전송합니다.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "DragonBreedingNFT : No ETH to withdraw");
        payable(msg.sender).transfer(balance);
    }
}