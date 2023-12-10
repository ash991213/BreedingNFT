## TODO

-   테스트 코드 작성

-   드래곤 교배 시 희귀도 설정 함수 재확인

-   드래곤 교배 후 드래곤 대여자에게 수수료 지급 확인

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

2. Chainlink VRF의 로컬 테스트 환경에서는 체인링크 VRF 노드가 존재하지 않아 실제와 같은 랜덤값을 생성하는데 어려움이 있음

예 : local에서 ganache를 사용해서 테스트시 테스트 실행마다 랜덤값이 동일하여 같은 등급, 종류, 데미지의 드래곤이 생성됨

해결 방안 :

local에서 모든 함수에 대한 테스트를 마친 후 공개 테스트넷(ex : Sepolia, Mumbai)에서 철저하게 테스트 예정(Chainlink에서도 이를 권장함)
