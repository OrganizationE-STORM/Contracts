// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {EStormOracle} from "./EStormOracle.sol";
import {Bolt} from "./Bolt.sol";
import {console} from "forge-std/console.sol";

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
        uint256 lastRewardUpdate;
        uint256 totalStaked;
        uint256 totalShares;
    }

    mapping(bytes32 => PoolInfo) public poolInfo; // the key is obtained by concatenating the _gameID, _challengeID and the _userID
    mapping(string => bool) public gamesRegistered;
    mapping(string => bool) public usersRegistered;
    mapping(bytes32 => mapping(address => uint256)) sharesByAddress;

    address public immutable token;
    EStormOracle public oracle;

    constructor(address _token, EStormOracle _oracle) Ownable(_msgSender()) {
        token = _token;
        oracle = _oracle;
    }

    function createPool(
        uint8 _toCover,
        uint8 _toDistribute,
        string memory _gameID,
        string memory _challengeID,
        string memory _userID
    ) public onlyOwner {
        require(gamesRegistered[_gameID], "Game not registered");

        if (!usersRegistered[_userID]) {
            usersRegistered[_userID] = true;
        }

        bytes32 poolID = keccak256(abi.encode(_gameID, _challengeID, _userID));
        require(poolInfo[poolID].toCover == 0, "Pool already exists");

        //q: when we create the pool, should the lastRewardUpdate be block.timestamp?
        poolInfo[poolID] = PoolInfo({
            toCover: _toCover,
            toDistribute: _toDistribute,
            id: poolID,
            userID: _userID,
            lastRewardUpdate: block.timestamp,
            totalStaked: 0,
            totalShares: 0
        });

        emit PoolCreated(
            _gameID,
            _challengeID,
            _userID,
            _toCover,
            _toDistribute
        );
    }

    function deposit(uint256 _amount, bytes32 _pid) public {
        (bool isActive, int256 rewardAmount, uint256 lastRewardUpdate) = oracle
            .getPool(_pid);
        require(isActive, "Pool not active");
        PoolInfo storage pool = poolInfo[_pid];
        
        //q: bombard this part with tests
        if (lastRewardUpdate > pool.lastRewardUpdate) {
            pool.lastRewardUpdate = block.timestamp;
            if (rewardAmount > 0) {
                //TODO: Safe transfer function here
                pool.totalStaked += uint256(rewardAmount);
            } else {
                uint256 absRewardAmount = uint256(-rewardAmount);
                require(
                    pool.totalStaked >= absRewardAmount,
                    "Reward exceeds total staked"
                );
                pool.totalStaked -= absRewardAmount;
            }
        }

        if(pool.totalShares == 0) {
            pool.totalStaked = _amount;
            pool.totalShares = 100000;
            sharesByAddress[_pid][msg.sender] = 100000;
        } else {
            pool.totalStaked += _amount;
            uint256 shares = pool.totalShares / (1 - _amount / pool.totalStaked) - pool.totalShares;
            pool.totalShares += shares;
            sharesByAddress[_pid][msg.sender] += shares;
        }
    }

    function getPool(bytes32 _pid) public view returns (PoolInfo memory) {
        return poolInfo[_pid];
    }

    function addGame(string memory _game) external onlyOwner {
        gamesRegistered[_game] = true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
