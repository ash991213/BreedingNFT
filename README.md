## TODO

-   테스트 코드 작성

-   Ganache 테스트 완료 후 Sepolia 네트워크에서 loadFixture 사용

## ISSUE

1. TestVRFv2Consumer 컨트랙트의 fulfillRandomWords 함수 문제 해결

문제점 :

TestVRFCoordinatorV2Mock 컨트랙트에서 fulfillRandomWords 함수를 호출하였으나, 내부 로직에서 오류가 발생하여 정상적으로 작동하지 않음. dragonNft.mintNewDragon 함수는 정상적으로 작동하지만, dragonBreed.breedDragons 함수에서 문제가 발견됨.

해결 방안 :

dragonNft 인터페이스의 파라미터 타입에 오류가 있었으며, 이를 수정함.
변경 전: createDragon 함수의 \_damage 파라미터는 uint16 타입, \_xpPerSec 파라미터는 uint8 타입으로 선언됨.
변경 후: \_damage를 uint64 타입으로, \_xpPerSec를 uint32 타입으로 변경하여 타입 불일치 문제 해결.

```typescript
<!-- 변경 전 -->
function createDragon(address _to, DragonNFTLib.Gender _gender, DragonNFTLib.Rarity _rarity, DragonNFTLib.Species _specie, uint16 _damage, uint8 _xpPerSec) external returns(uint256 tokenId);

<!-- 변경 후 -->
function createDragon(address _to, DragonNFTLib.Gender _gender, DragonNFTLib.Rarity _rarity, DragonNFTLib.Species _specie, uint64 _damage, uint32 _xpPerSec) external returns(uint256 tokenId);
```

차후 대처 계획 :
Slither와 같은 정적 스마트 컨트랙트 분석 도구 사용
