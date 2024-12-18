// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EStormOracle is Ownable {
  event PoolUpdated(bytes32 pid, int256 dept, bool isActive);

  struct PoolInfo {
    bool isActive;
    int256 dept;
  }

  mapping(bytes32 => PoolInfo) public infoByPID;

  constructor() Ownable(_msgSender()) {}

  function updatePool(bytes32 _pid, int256 _dept, bool _isActive) public onlyOwner() {
    infoByPID[_pid].isActive = _isActive;
    infoByPID[_pid].dept = _dept;
    emit PoolUpdated(_pid, _dept, _isActive);
  }

  function getPool(bytes32 _pid) external view returns(PoolInfo memory) {
    return infoByPID[_pid];
  }
  
}