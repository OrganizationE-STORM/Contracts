// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EStormOracle is Ownable {
  event PoolUpdated(bytes32 pid, int256 dept, bool isActive, uint256 lastRewardUpdate);

  struct PoolInfo {
    bool isActive;
    int256 dept;
    bool shouldCountReward;
  }

  mapping(bytes32 => PoolInfo) public infoByPID;

  address public stakingContract;

  constructor() Ownable(_msgSender()) {}

  function updatePool(bytes32 _pid, int256 _dept, bool _isActive) public onlyOwner() {
    infoByPID[_pid].isActive = _isActive;
    infoByPID[_pid].dept = _dept;
    infoByPID[_pid].shouldCountReward = true;
    emit PoolUpdated(_pid, _dept, _isActive, block.timestamp);
  }

  function lockReward(bytes32 _pid) public {
    require(msg.sender == stakingContract);
    infoByPID[_pid].shouldCountReward = false;
    infoByPID[_pid].dept = 0;
  }

  function setStakingContract(address _addr) public onlyOwner {
    stakingContract = _addr;
  }

  function getPool(bytes32 _pid) external view returns(bool, int256, bool) {
    return (infoByPID[_pid].isActive, infoByPID[_pid].dept, infoByPID[_pid].shouldCountReward);
  }
}