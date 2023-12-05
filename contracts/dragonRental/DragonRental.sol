// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../dragonNFT/interface/IDragonNFT.sol";
import "../operator/interface/IOperator.sol";

import "./library/DragonRentalLib.sol";

contract DragonRental {
    IOperator private immutable operator;
    IDragonNFT private dragonNft;
    
    // 드래곤 대여 정보를 저장하는 매핑
    mapping(uint256 => DragonRentalLib.DragonRental) public dragonRentals;

    // 대여중인 드래곤 배열
    uint256[] private rentedDragons;

    event DragonRented(uint256 indexed tokenId, address indexed renter, uint256 duration);
    event DragonRentalCancelled(uint256 indexed tokenId, address indexed renter, uint256 cancledTime);

    constructor(address _operator, address _dragonNft) {
        operator = IOperator(_operator);
        dragonNft = IDragonNFT(_dragonNft);
    }

    // 드래곤을 대여합니다.
    function rentDragon(uint256 tokenId) external {
        require(dragonNft.ownerOf(tokenId) == msg.sender, "DragonRental : Not owner.");
        require(!dragonRentals[tokenId].isRented, "DragonRental : Already rented.");

        dragonRentals[tokenId] = DragonRentalLib.DragonRental({
            isRented : true,
            startTime : block.timestamp,
            duration : block.timestamp + 48 hours,
            renter : msg.sender
        });

        rentedDragons.push(tokenId);

        emit DragonRented(tokenId, msg.sender, block.timestamp + 48 hours);
    }

    // 드래곤 대여를 취소합니다.
    function cancelRental(uint256 tokenId) external {
        require(dragonRentals[tokenId].renter == msg.sender || operator.isOperator(msg.sender), "DragonRental: Not renter or Operator.");
        require(isRentalActive(tokenId), "DragonRental: Rental not active.");

        address renter = dragonRentals[tokenId].renter;
        delete dragonRentals[tokenId];

        for (uint256 i = 0; i < rentedDragons.length; i++) {
            if (rentedDragons[i] == tokenId) {
                rentedDragons[i] = rentedDragons[rentedDragons.length - 1];
                rentedDragons.pop();
                break;
            }
        }

        emit DragonRentalCancelled(tokenId, renter, block.timestamp);
    }

    // 현재 대여 중인 드래곤 목록 조회
    function getCurrentlyRentedDragons() public view returns (uint256[] memory) {
        return rentedDragons;
    }

    // 드래곤이 대여 가능한 상태인지 확인합니다.
    function isRentalActive(uint256 tokenId) public view returns (bool) {
        DragonRentalLib.DragonRental memory rental = dragonRentals[tokenId];
        return rental.isRented && (block.timestamp - rental.startTime) <= rental.duration;
    }

    // 드래곤 대여 정보를 반환합니다.
    function getDragonRental(uint256 tokenId) public view returns(DragonRentalLib.DragonRental memory dragonRental) {
        return dragonRentals[tokenId];
    }
}