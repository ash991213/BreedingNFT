// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

import "../dragonBreedingNFT/DragonBreedingNFT.sol";

contract VRFv2Consumer is VRFConsumerBaseV2, ConfirmedOwner, DragonBreedingNFT {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    enum RequestPurpose { 
        MINTING,
        BREEDING
    }

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        RequestPurpose requestPurpose;
        address requester;
        uint256[] randomWords;
    }

    struct BreedingRequest {
        uint256 parent1TokenId;
        uint256 parent2TokenId;
    }

    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

    mapping(uint256 => BreedingRequest) public breedingRequests;

    VRFCoordinatorV2Interface COORDINATOR;

    // subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    uint32 callbackGasLimit = 300000;

    uint16 requestConfirmations = 3;

    uint32 numWords = 4;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(uint64 subscriptionId, uint8 _maxLevel, uint32[] memory _xpToLevelUp) VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625) ConfirmedOwner(msg.sender) DragonBreedingNFT(_maxLevel, _xpToLevelUp) {
        COORDINATOR = VRFCoordinatorV2Interface(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        s_subscriptionId = subscriptionId;
    }

    // 신규 드래곤 생성 함수
    function mintNewDragon() external payable returns (uint256 requestId) {
        require(msg.value == NFT_MINT_FEE, "DragonBreedingNFT : Incorrect ETH amount");
        return requestRandomWordsForPurpose(RequestPurpose.MINTING, 0, 0);
    }

    // 드래곤 교배 함수
    function breedDragons(uint256 parent1TokenId, uint256 parent2TokenId) external payable returns (uint256 requestId) {
        require(msg.value == BREEDING_FEE, "DragonBreedingNFT : Incorrect ETH amount");
        require(ownerOf(parent1TokenId) != address(0) && ownerOf(parent2TokenId) != address(0), "DragonBreedingNFT : Dragon does not exist");
        require(_isDragonOwnedOrRentedBySender(parent1TokenId) || _isDragonOwnedOrRentedBySender(parent2TokenId), "At least one dragon must be owned or rented by the caller.");

        Gender parent1Gender = getDragonGender(parent1TokenId);
        Gender parent2Gender = getDragonGender(parent2TokenId);

        require(parent1Gender != parent2Gender, "DragonBreedingNFT : Dragons must be of different genders");
        require(block.timestamp >= lastBreedingTime[parent1TokenId] + BREEDING_COOL_DOWN && block.timestamp >= lastBreedingTime[parent2TokenId] + BREEDING_COOL_DOWN, "DragonBreedingNFT : Breeding cooldown active");
        
        return requestRandomWordsForPurpose(RequestPurpose.BREEDING, parent1TokenId, parent2TokenId);
    }

    // Chainlink VRF 랜덤값 요청 함수
    function requestRandomWordsForPurpose(RequestPurpose _purpose, uint256 _parent1TokenId, uint256 _parent2TokenId) internal returns(uint256 requestId) {
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            requestPurpose : _purpose,
            requester : msg.sender,
            fulfilled: false
        });

        if (_purpose == RequestPurpose.BREEDING) {
            breedingRequests[requestId] = BreedingRequest({
                parent1TokenId : _parent1TokenId,
                parent2TokenId : _parent2TokenId
            });
        }

        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    // Chainlink VRF를 통해 랜덤 숫자를 받아 새로운 드래곤 NFT를 발행합니다.
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        if(s_requests[_requestId].requestPurpose == RequestPurpose.MINTING) {
            mintNewDragon(s_requests[_requestId].requester, _randomWords);
        } else if(s_requests[_requestId].requestPurpose == RequestPurpose.BREEDING) {
            breedDragons(s_requests[_requestId].requester, breedingRequests[_requestId].parent1TokenId, breedingRequests[_requestId].parent2TokenId, _randomWords);
            distributeBreedingFee(breedingRequests[_requestId].parent1TokenId, breedingRequests[_requestId].parent2TokenId);
        }
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint256 _requestId) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    // 스마트 컨트랙트에 저장된 이더리움을 스마트 컨트랙트 소유자에게 전송합니다.
    function withdraw() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "DragonBreedingNFT : No ETH to withdraw");
        payable(msg.sender).transfer(balance);
    }
}
