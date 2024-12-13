// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MyContract is Pausable, Ownable {

    struct PoolInfo {
        uint8 toCover;      
        uint8 toDistribute; 
    }

    mapping(bytes32 => PoolInfo) public poolInfo; // the key is obtained by concatenating the _gameID, _challengeID and the _userID
    mapping(string => bool) public gamesRegistered;
    mapping(string => bool) public usersRegistered;
    
    constructor(address _initialOwner) Ownable(_initialOwner) {}

    function createPool(uint8 _toCover, uint8 _toDistribute, string memory _gameID, string memory _challengeID, string memory _userID) 
        public 
        onlyOwner()
    {

    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}