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

    event Deposit(address staker, uint256 amount, bytes32 pid);

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

    uint256 public constant SCALE = 1e28;
    uint256 public constant INITIAL_SHARES = 100_000 * SCALE;

    address public devaddr;
    EStormOracle public oracle;
    Bolt public immutable bolt;

    //TODO: add max circulating supply max circulating supply (1e16)
    //TODO: at the starting sale: 6 * 1e14

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
    ) external onlyOwner {
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

    function deposit(uint256 _amount, bytes32 _pid) external {
        require(_amount > 0, "Amount cannot be zero");

        (bool isActive, int256 rewardAmount, bool shouldCountReward) = oracle
            .getPool(_pid);
        require(isActive, "Pool not active");

        if (shouldCountReward) consumeReward(rewardAmount, _pid);
        updatePoolInfo(_pid, _amount);

        bolt.transferFrom(_msgSender(), address(this), _amount);
        emit Deposit(_msgSender(), _amount, _pid);
    }

    function withdraw(bytes32 _pid) external {
        (bool isActive, int256 rewardAmount, bool shouldCountReward) = oracle
            .getPool(_pid);
        require(isActive, "Pool not active");

        if (shouldCountReward) consumeReward(rewardAmount, _pid);

        PoolInfo storage pool = poolInfo[_pid];
        

        pool.totalStaked -= scaledAmount;
        sharesByAddress[_pid][_msgSender()] = 0;
    }

    //TODO: add the check on the total supply if rewardAmount is positive
    function consumeReward(int256 _rewardAmount, bytes32 _pid) private {
        PoolInfo storage pool = poolInfo[_pid];
        if (_rewardAmount > 0) {
            pool.totalStaked += uint256(_rewardAmount);
            safeEBoltTransfer(address(this), uint256(_rewardAmount));
        } else if (_rewardAmount < 0) {
            uint256 absRewardAmount = uint256(-_rewardAmount);
            require(
                pool.totalStaked >= absRewardAmount,
                "Reward amount value not valid"
            );
            pool.totalStaked -= absRewardAmount;
            safeEBoltTransfer(devaddr, absRewardAmount);
        }
        oracle.lockReward(_pid);
    }

    function updatePoolInfo(bytes32 _pid, uint256 _amount) private {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 totalStakedTmp = pool.totalStaked;
        uint256 totalSharesTmp = pool.totalShares;

        if (pool.totalShares == 0) {
            pool.totalStaked += _amount;
            pool.totalShares = INITIAL_SHARES / SCALE;
            sharesByAddress[_pid][_msgSender()] = INITIAL_SHARES / SCALE;
        } else {
            pool.totalStaked += _amount;

            pool.totalShares =
                (((totalSharesTmp * SCALE) / totalStakedTmp) *
                    pool.totalStaked) /
                SCALE;

            sharesByAddress[_pid][_msgSender()] +=
                pool.totalShares -
                totalSharesTmp;
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

    function setOracle(EStormOracle _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function setDevAddress(address _addr) external onlyOwner {
        devaddr = _addr;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
