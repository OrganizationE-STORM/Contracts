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
    mapping(bytes32 => mapping(address => uint256)) public sharesByAddress;

    uint256 constant PRECISION_FACTOR = 1e12;
    uint256 constant INITIAL_SHARES = 100000 * PRECISION_FACTOR;

    address public devaddr;
    EStormOracle public oracle;
    Bolt public immutable bolt;

    constructor(
        Bolt _bolt,
        EStormOracle _oracle,
        address _devaddr
    ) Ownable(_msgSender()) {
        bolt = _bolt;
        oracle = _oracle;
        devaddr = _devaddr;
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
        require(_amount > 0, "Amount cannot be zero");
        (bool isActive, int256 rewardAmount, uint256 lastRewardUpdate) = oracle
            .getPool(_pid);
        require(isActive, "Pool not active");
        PoolInfo storage pool = poolInfo[_pid];
        
        if (lastRewardUpdate > pool.lastRewardUpdate) {
            pool.lastRewardUpdate = block.timestamp;
            
            if (rewardAmount > 0) {
                pool.totalStaked += uint256(rewardAmount);
                safeEBoltTransfer(address(this), uint256(rewardAmount));
            } else if (rewardAmount < 0) {
                uint256 absRewardAmount = uint256(-rewardAmount);
                require(
                    pool.totalStaked >= absRewardAmount,
                    "Reward exceeds total staked"
                );
                // add an if statement
                pool.totalStaked -= absRewardAmount;
                safeEBoltTransfer(devaddr, absRewardAmount);
            }
        }

        if (pool.totalShares == 0) {
            pool.totalStaked += _amount;
            pool.totalShares = INITIAL_SHARES / PRECISION_FACTOR;
            sharesByAddress[_pid][msg.sender] = INITIAL_SHARES / PRECISION_FACTOR;
        } else {
            uint256 shares = (_amount * pool.totalShares * PRECISION_FACTOR) / (pool.totalStaked * PRECISION_FACTOR);
            pool.totalStaked += _amount;
            pool.totalShares += shares;
            sharesByAddress[_pid][msg.sender] += shares;
        }
    }

    function safeEBoltTransfer(address _to, uint256 _amount) internal {
        bolt.safeEBoltTransfer(_to, _amount);
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
