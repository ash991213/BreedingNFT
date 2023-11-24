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

import "../utils/IDragonAttributesDeterminer.sol";

contract DragonMintingNFT is ERC721, Ownable {
    IDragonAttributesDeterminer private dragonAttributesDeterminer;
    IVRFv2Consumer private vrfConsumer;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // 최고 레벨
    uint8 MAX_LEVEL;

    // 레벨업 하는데 필요한 경험치 배열
    uint32[] public xpToLevelUp;

    // 드래곤 발행 수수료
    uint256 public constant NFT_MINT_FEE = 0.01 ether;

    event NewDragonBorn(uint256 _tokenId, Gender _gender, Rarity _rarity, Species _specie, uint64 _damage, uint256 _lastInteracted, uint32 _xpPerSec);
    event DragonExperienceGained(uint256 _tokenId, uint8 _level, uint32 _xp, uint32 _xpToAdd);
    event DragonLevelUp(uint256 _tokenId, uint8 _level, uint32 _xp, uint64 _damage);
    event DragonLevelXPAdjusted(uint8 level, uint32 previousXP, uint32 newXP);
    event DragonMaxLevelReached(uint256 _tokenId, Gender _gender, Rarity _rarity, Species _specie, uint64 _damage, uint8 _level);

    // _xpToLevelUp 비선형적으로 계산해서 인자값으로 받습니다.
    constructor(uint8 _maxLevel, uint32[] memory _xpToLevelUp, address _vrfConsumer, address _dragonAttributesDeterminer) ERC721("Dragon Rearing","DR") {
        require(_maxLevel == _xpToLevelUp.length, "DragonBreedingNFT : Max level and xp array length must match");
        MAX_LEVEL = _maxLevel;
        xpToLevelUp = _xpToLevelUp;
        vrfConsumer = IVRFv2Consumer(_vrfConsumer);
        dragonAttributesDeterminer = IDragonAttributesDeterminer(_dragonAttributesDeterminer);
    }

    // 신규 드래곤 생성 함수
    function mintNewDragon() external payable returns (uint256 requestId) {
        require(msg.value == NFT_MINT_FEE, "DragonBreedingNFT : Incorrect ETH amount");
        return vrfConsumer.requestRandomWordsForPurpose(RequestPurpose.MINTING, 0, 0);
    }

    // 신규 드래곤 NFT 생성
    function _mintNewDragon(address requester, uint256[] memory _randomWords) internal {
        Gender gender = dragonAttributesDeterminer.determineGender(_randomWords[0]);
        Rarity rarity = dragonAttributesDeterminer.determineRarity(_randomWords[1]);
        Species specie = dragonAttributesDeterminer.determineSpecies(rarity, _randomWords[2]);
        uint64 damage = dragonAttributesDeterminer.determineDamage(rarity, _randomWords[3]);
        uint32 xpPerSec = dragonAttributesDeterminer.determineExperience(rarity);

        uint256 _tokenId = createDragon(requester, gender, rarity, specie, damage, xpPerSec);
        emit NewDragonBorn(_tokenId, gender, rarity, specie, damage, block.timestamp, xpPerSec);
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