// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract StakingContract is Pausable, Ownable {

     event PoolCreated(
        string gameID,
        string challengeID,
        string userID,
        uint8 toCover,
        uint8 toDistribute
    );

    struct PoolInfo {
        bytes32 id;
        uint8 toCover;      
        uint8 toDistribute;
        string userID; 
    }

    mapping(bytes32 => PoolInfo) public poolInfo; // the key is obtained by concatenating the _gameID, _challengeID and the _userID
    mapping(string => bool) public gamesRegistered;
    mapping(string => bool) public usersRegistered;
    
    address public immutable token;

    constructor(address _token) Ownable(_msgSender()) {
        token = _token;
    }

    function createPool(uint8 _toCover, uint8 _toDistribute, string memory _gameID, string memory _challengeID, string memory _userID) 
        public 
        onlyOwner()
    {
        require(gamesRegistered[_gameID], "Game not registered");

        if(!usersRegistered[_userID]) {
            usersRegistered[_userID] = true;
        }

        bytes32 poolID = keccak256(abi.encode(_gameID, _challengeID, _userID));
        require(poolInfo[poolID].toCover == 0, "Pool already exists");

        poolInfo[poolID] = PoolInfo({toCover: _toCover, toDistribute: _toDistribute, id: poolID, userID: _userID});

        emit PoolCreated(_gameID, _challengeID, _userID, _toCover, _toDistribute);
    }

    function getPool(bytes32 _pid) public view returns(PoolInfo memory) {
        return poolInfo[_pid];
    }

    function addGame(string memory _game) external onlyOwner() {
        gamesRegistered[_game] = true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}