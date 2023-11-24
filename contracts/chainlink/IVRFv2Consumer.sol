// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RequestPurpose.sol";

interface IVRFv2Consumer {
    function requestRandomWordsForPurpose(RequestPurpose _purpose, uint256 _parent1TokenId, uint256 _parent2TokenId) external returns(uint256 requestId);
}