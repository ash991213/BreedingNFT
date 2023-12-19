// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// * chainlink VRF
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

// * libraries
import "../dragonNFT/library/DragonNFTLib.sol";
import "../dragonBreed/library/DragonBreedLib.sol";

// * interfaces
import "../dragonNFT/interface/IDragonNFT.sol";
import "../dragonRental/interface/IDragonRental.sol";
import "../dragonBreed/interface/IDragonBreed.sol";

contract VRFv2Consumer is VRFConsumerBaseV2, ConfirmedOwner, ReentrancyGuard {
    IDragonNFT private immutable dragonNft;
    IDragonRental private immutable dragonRental;
    IDragonBreed private immutable dragonBreed;
    VRFCoordinatorV2Interface immutable coordinator;

    // Chainlink VRF 구독 ID
    uint64 immutable subscriptionId;

    // 특정 Chainlink VRF 노드의 고유 식별자
    bytes32 constant KEY_HASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // 콜백 함수 가스 한도
    uint32 constant CALLBACK_GASLIMIT = 3_000_000;

    // Request Confirm 횟수 -> 높일 시 더 안정적으로 랜덤값을 가져오지만 속도가 오래걸림 평균 - 3
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    // 요청할 랜덤 단어 수
    uint32 constant NUM_WORDS = 4;

    // 드래곤 발행 수수료
    uint256 public constant NFT_MINT_FEE = 1 ether;

    // 요청 타입 (Mint, Breed)
    enum RequestPurpose {
        MINTING,
        BREEDING
    }

    // request 상태 구조체
    struct RequestStatus {
        bool fulfilled;
        bool exists;
        RequestPurpose requestPurpose;
        uint256 rentedDragonTokenId;
        address requester;
        uint256[] randomWords;
    }

    // 드래곤 교배에 사용할 부모 드래곤 tokenId 구조체
    struct DragonBreedingPair {
        uint256 parent1TokenId;
        uint256 parent2TokenId;
    }

    // requestId에 대한 상태 저장 매핑
    mapping(uint256 => RequestStatus) public requests;

    // Request Id에 연결된 부모 드래곤 tokenId
    mapping(uint256 => DragonBreedingPair) public breedingRequests;

    // 사용자별로 인출할 수 있는 잔액을 추적합니다.
    mapping(address => uint256) private pendingWithdrawals;

    event RequestSent(uint256 requestId, uint32 numWords, RequestPurpose requestPurpose, uint256 rentedDragonTokenId);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords, RequestPurpose requestPurpose);

    /**
     * HARDCODED FOR SEPOLIA COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(uint64 _subscriptionId, address _dragonNft, address _dragonRental, address _dragonBreed) VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625) ConfirmedOwner(msg.sender) {
        coordinator = VRFCoordinatorV2Interface(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        subscriptionId = _subscriptionId;
        dragonNft = IDragonNFT(_dragonNft);
        dragonRental = IDragonRental(_dragonRental);
        dragonBreed = IDragonBreed(_dragonBreed);
    }

    // 드래곤을 생성하는 함수입니다.
    function mintNewDragon() external payable returns (uint256 requestId) {
        require(msg.value == NFT_MINT_FEE, "DragonBreed : Incorrect ETH amount");
        return requestRandomWordsForPurpose(RequestPurpose.MINTING, 0, 0, 0);
    }

    // 드래곤을 교배시키는 함수입니다.
    function breedDragons(uint256 parent1TokenId, uint256 parent2TokenId) external payable returns (uint256 requestId) {
        require(msg.value == DragonBreedLib.BREEDING_FEE, "DragonBreed : Incorrect ETH amount");

        // 각 드래곤의 소유자 또는 대여 상태 확인
        bool isParent1OwnedOrRented = dragonNft.ownerOf(parent1TokenId) == msg.sender || dragonRental.isRentalActive(parent1TokenId);
        bool isParent2OwnedOrRented = dragonNft.ownerOf(parent2TokenId) == msg.sender || dragonRental.isRentalActive(parent2TokenId);
        require(isParent1OwnedOrRented && isParent2OwnedOrRented, "DragonBreed : Both dragons must be owned or rented by the caller.");
        // 두 드래곤이 모두 대여인경우 상태인 경우 교배 불가
        require(!(dragonRental.isRentalActive(parent1TokenId) && dragonRental.isRentalActive(parent2TokenId)), "DragonBreed : Both dragons cannot be rented");

        // 드래곤의 성별 확인
        DragonNFTLib.Gender parent1Gender = dragonNft.getDragonInfo(parent1TokenId).gender;
        DragonNFTLib.Gender parent2Gender = dragonNft.getDragonInfo(parent2TokenId).gender;
        require(parent1Gender != parent2Gender, "DragonBreed : Dragons must be of different genders");

        // 교배 쿨다운 확인
        uint256 parent1LastBreedingTime = dragonBreed.getLastBreedingTime(parent1TokenId);
        uint256 parent2LastBreedingTime = dragonBreed.getLastBreedingTime(parent2TokenId);
        require(block.timestamp >= parent1LastBreedingTime + DragonBreedLib.BREEDING_COOL_DOWN && block.timestamp >= parent2LastBreedingTime + DragonBreedLib.BREEDING_COOL_DOWN, "DragonBreed : Breeding cooldown active");

        // 대여한 드래곤 확인
        uint256 rentedDragonTokenId;
        bool isParent1Rented = !(dragonNft.ownerOf(parent1TokenId) == msg.sender);
        bool isParent2Rented = !(dragonNft.ownerOf(parent2TokenId) == msg.sender);
        
        if(isParent1Rented && isParent2Rented) {
            rentedDragonTokenId = 0;
        } else {
            rentedDragonTokenId = isParent1Rented ? parent1TokenId : parent2TokenId;
        }

        // 교배 요청 처리
        return requestRandomWordsForPurpose(RequestPurpose.BREEDING, parent1TokenId, parent2TokenId, rentedDragonTokenId);
    }

    // Chainlink VRF 랜덤값을 요청하는 함수입니다.
    function requestRandomWordsForPurpose(RequestPurpose purpose, uint256 parent1TokenId, uint256 parent2TokenId, uint256 rentedDragonTokenId) internal nonReentrant returns(uint256 requestId) {
        require(address(coordinator) != address(0), "DragonBreed: Invalid VRFCoordinator address");

        requestId = coordinator.requestRandomWords(
            KEY_HASH,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GASLIMIT,
            NUM_WORDS
        );

        require(requestId > 0, "DragonBreed: Failed to request random words");

        requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            requestPurpose : purpose,
            rentedDragonTokenId : rentedDragonTokenId,
            requester : msg.sender,
            fulfilled: false
        });

        if (purpose == RequestPurpose.BREEDING) {
            breedingRequests[requestId] = DragonBreedingPair({
                parent1TokenId : parent1TokenId,
                parent2TokenId : parent2TokenId
            });
        }

        emit RequestSent(requestId, NUM_WORDS, purpose, rentedDragonTokenId);
        return requestId;
    }

    // Chainlink VRF를 통해 랜덤 숫자를 받아 새로운 드래곤 NFT를 발행합니다.
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override nonReentrant {
        require(requests[requestId].exists, "request not found");
        requests[requestId].fulfilled = true;
        requests[requestId].randomWords = randomWords;

        if(requests[requestId].requestPurpose == RequestPurpose.MINTING) {
            dragonNft.mintNewDragon(requests[requestId].requester, randomWords);
        } else if(requests[requestId].requestPurpose == RequestPurpose.BREEDING) {
            dragonBreed.breedDragons(requests[requestId].requester, breedingRequests[requestId].parent1TokenId, breedingRequests[requestId].parent2TokenId, randomWords, requests[requestId].rentedDragonTokenId);
            (address renter, uint256 rentalFee) = dragonBreed.distributeBreedingFee(breedingRequests[requestId].parent1TokenId, breedingRequests[requestId].parent2TokenId);
            address contractOwner = owner();

            uint256 fee = DragonBreedLib.BREEDING_FEE - rentalFee;
            pendingWithdrawals[renter] += rentalFee;
            pendingWithdrawals[contractOwner] += fee;
        }
        emit RequestFulfilled(requestId, randomWords, requests[requestId].requestPurpose);
    }

    // 대여 수수료를 확인합니다.
    function getFeeAmount() external view returns(uint256 amount) {
        return pendingWithdrawals[msg.sender];
    }

    // 드래곤 대여자들이 수수료를 요청하는 함수입니다.
    function withdrawFee() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds available");

        // 잔액을 0으로 설정하고 이더를 전송합니다.
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}