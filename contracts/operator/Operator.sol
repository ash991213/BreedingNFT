// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// * accesses
import "@openzeppelin/contracts/access/Ownable.sol";

// * interfaces
import "./interface/IOperator.sol";

contract OperatorManager is Ownable, IOperator {

    mapping(address => bool) public operatorMap;

    event AddOperator(address account);
    event RemoveOperator(address account);

    constructor() {
        operatorMap[msg.sender] = true;
    }

    function addOperator(address account) external onlyOwner {
        operatorMap[account] = true;
        emit AddOperator(account);
    }

    function removeOperator(address account) external onlyOwner {
        operatorMap[account] = false;
        emit RemoveOperator(account);
    }

    function isOperator(address account) external view override returns (bool) {
        return operatorMap[account];
    }
}