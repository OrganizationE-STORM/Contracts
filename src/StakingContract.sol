// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {EStormOracle} from "./EStormOracle.sol";
import {Bolt} from "./Bolt.sol";
import {console} from "forge-std/console.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract StakingContract is Pausable, Ownable {
    using Math for uint256;

    event PoolCreated(
        string gameID,
        string challengeID,
        string userID,
        uint8 toCover,
        uint8 toDistribute
    );

    event Deposit(address staker, uint256 amount, bytes32 pid);
    event Withdraw(address staker, uint256 amount, uint256 fee, bytes32 pid);

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

    uint256 public constant SCALE = 1e30;
    uint256 public constant INITIAL_SHARES = 100_000 * SCALE;
    uint8 public feePerc = 2;

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

        uint256 shares = previewDeposit(_amount, _pid);

        if (shouldCountReward) consumeReward(rewardAmount, _pid);

        updatePoolInfo(_pid, _amount, shares);

        bolt.transferFrom(_msgSender(), address(this), _amount);
        emit Deposit(_msgSender(), _amount, _pid);
    }

    function updatePoolInfo(
        bytes32 _pid,
        uint256 _amount,
        uint256 _shares
    ) private {
        PoolInfo storage pool = poolInfo[_pid];

        pool.totalStaked += _amount;
        pool.totalShares += _shares;

        sharesByAddress[_pid][_msgSender()] += _shares;
    }

    function withdraw(bytes32 _pid, uint256 _amount) public {
        (bool isActive, int256 rewardAmount, bool shouldCountReward) = oracle
            .getPool(_pid);
        require(isActive, "Pool not active");

        uint256 shares = previewWithdraw(_amount, _pid);
        
       
        uint256 fee = previewFee(_amount, _pid);

        if (shouldCountReward) consumeReward(rewardAmount, _pid);

        require(
            shares <= sharesByAddress[_pid][_msgSender()],
            "Shares amount not valid"
        );

        updatePoolInfoAfterWithdraw(_pid, _amount, shares, fee);
        safeEBoltTransfer(devaddr, fee);
        safeEBoltTransfer(_msgSender(), _amount);
        emit Withdraw(_msgSender(), _amount, fee, _pid);
    }

    function convertToAssets(
        uint256 _shares,
        bytes32 _pid
    ) public view returns (uint256) {
        (, int256 rewardAmount, ) = oracle.getPool(_pid);

        PoolInfo memory pool = poolInfo[_pid];
        uint256 tokens = pool.totalStaked;

        if (rewardAmount < 0) {
            tokens -= uint256(-rewardAmount);
        } else {
            tokens += uint256(rewardAmount);
        }

        return
            _shares.mulDiv(
                tokens + 1,
                pool.totalShares + 10 ** bolt.decimals(),
                Math.Rounding.Ceil
            );
    }

    function _convertToShares(
        uint256 _amount,
        bytes32 _pid,
        Math.Rounding rounding
    ) public view returns (uint256) {
        (, int256 rewardAmount, ) = oracle.getPool(_pid);

        PoolInfo memory pool = poolInfo[_pid];
        uint256 tokens = pool.totalStaked;

        if (rewardAmount < 0) {
            tokens -= uint256(-rewardAmount);
        } else {
            tokens += uint256(rewardAmount);
        }

        return
            _amount.mulDiv(
                pool.totalShares + 10 ** bolt.decimals(),
                tokens + 1,
                rounding
            );
    }

    function previewWithdraw(
        uint256 _amount,
        bytes32 _pid
    ) public view returns (uint256) {
        uint256 shares = _convertToShares(_amount, _pid, Math.Rounding.Ceil);

         if(shares > sharesByAddress[_pid][_msgSender()]) 
            shares = sharesByAddress[_pid][_msgSender()];

        return shares;
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

    function updatePoolInfoAfterWithdraw(
        bytes32 _pid,
        uint256 _amount,
        uint256 _shares,
        uint256 _fee
    ) private {
        PoolInfo storage pool = poolInfo[_pid];
        pool.totalStaked -= _amount;
        _amount -= _fee;
        pool.totalShares -= _shares;
        sharesByAddress[_pid][_msgSender()] -= _shares;
    }

    function previewDeposit(
        uint256 _amount,
        bytes32 _pid
    ) public view returns (uint256) {
        return _convertToShares(_amount, _pid, Math.Rounding.Floor);
    }

    function previewFee(
        uint256 _amount,
        bytes32 _pid
    ) public view returns (uint256) {
        return _amount.mulDiv(feePerc, 100, Math.Rounding.Ceil);
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

    function setDevFee(uint8 _newFee) external onlyOwner {
        feePerc = _newFee;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
