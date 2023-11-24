// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

import "../dragonBreedingNFT/DragonBreedingNFT.sol";
import "../dragonMintingNFT/DragonMintingNFT.sol";

contract VRFv2Consumer is VRFConsumerBaseV2, ConfirmedOwner {
    DragonMintingNFT private dragonMintingNFT;
    DragonBreedingNFT private dragonBreedingNFT;
    
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        RequestPurpose requestPurpose;
        address requester;
        uint256[] randomWords;
    }

    struct BreedingRequest {
        uint256 parent1TokenId;
        uint256 parent2TokenId;
    }

    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    mapping(uint256 => BreedingRequest) public breedingRequests;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 300000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 4;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(
        uint64 subscriptionId
    )
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        s_subscriptionId = subscriptionId;
    }

    // Chainlink VRF 랜덤값 요청 함수
    function requestRandomWordsForPurpose(RequestPurpose _purpose, uint256 _parent1TokenId, uint256 _parent2TokenId) external returns(uint256 requestId) {
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
            dragonMintingNFT._mintNewDragon(s_requests[_requestId].requster, _randomWords);
        } else if(s_requests[_requestId].requestPurpose == RequestPurpose.BREEDING) {
            dragonBreedingNFT._breedDragons(s_requests[_requestId].requster, s_requests[_requestId].parent1TokenId, s_requests[_requestId].parent2TokenId, _randomWords);
            dragonBreedingNFT._distributeBreedingFee(breedingRequests[_requestId].parent1TokenId, breedingRequests[_requestId].parent2TokenId);
        }
        emit RequestFulfilled(_requestId, _randomWords);
    }


    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}
