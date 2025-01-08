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

    uint256 public constant SCALE = 1e28;
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

        if (shouldCountReward) consumeReward(rewardAmount, _pid);
        updatePoolInfo(_pid, _amount);

        bolt.transferFrom(_msgSender(), address(this), _amount);
        emit Deposit(_msgSender(), _amount, _pid);
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

    function withdraw(
        bytes32 _pid
    ) external returns (uint256 _stakerReward, uint256 _fee) {
        return _withdraw(_pid, 0, false);
    }

    function withdrawPartial(
        bytes32 _pid,
        uint256 _amount
    ) external returns (uint256 _stakerReward, uint256 _fee) {
        require(_amount > 0, "Amount must be greater than 0");
        return _withdraw(_pid, _amount, true);
    }

    function _withdraw(
        bytes32 _pid,
        uint256 _amount,
        bool isPartial
    ) private returns (uint256 _stakerReward, uint256 _fee) {
        (bool isActive, int256 rewardAmount, bool shouldCountReward) = oracle
            .getPool(_pid);
        require(isActive, "Pool not active");

        if (isPartial) {
            (uint256 _rewardToken, , ) = getUserReward(_pid, _msgSender());
            require(_amount <= _rewardToken, "Amount exceeds reward amount");
        }

        if (shouldCountReward) consumeReward(rewardAmount, _pid);

        uint256 fee;
        uint256 reward;

        if (isPartial) {
            fee = updatePoolInfoAfterWithdrawWithAmount(_pid, _amount);
            reward = _amount;
        } else {
            (fee, reward) = updatePoolInfoAfterWithdraw(_pid);
        }

        safeEBoltTransfer(devaddr, fee);
        safeEBoltTransfer(_msgSender(), reward);

        emit Withdraw(_msgSender(), reward, fee, _pid);

        return (reward, fee);
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
        bytes32 _pid
    ) private returns (uint256 _feeDevAddr, uint256 _reward) {
        PoolInfo storage pool = poolInfo[_pid];

        (
            uint256 _rewardToken,
            uint256 _fee,
            uint256 _currentShares
        ) = getUserReward(_pid, _msgSender());

        pool.totalStaked -= _rewardToken;
        _rewardToken -= _fee;

        pool.totalShares -= _currentShares;
        sharesByAddress[_pid][_msgSender()] = 0;

        return (_fee, _rewardToken);
    }

    function updatePoolInfoAfterWithdrawWithAmount(
        bytes32 _pid,
        uint256 _amount
    ) private returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        (, , uint256 _shares) = getUserReward(_pid, _msgSender());

        uint256 sharesToWithdraw = calculateSharesGivenTokens(_amount, _pid);
        uint256 fee = (_amount * feePerc * SCALE) / (100 * SCALE);

        require(sharesToWithdraw <= _shares, "Shares amount not valid");

        pool.totalStaked -= _amount;
        _amount -= fee;

        pool.totalShares -= _shares;
        sharesByAddress[_pid][_msgSender()] -= _shares;

        return fee;
    }

    function calculateSharesGivenTokens(
        uint256 _amount,
        bytes32 _pid
    ) private view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 totalStakedTmp = pool.totalStaked;
        uint256 totalSharesTmp = pool.totalShares;

        if (totalStakedTmp > totalSharesTmp) {
            uint256 ratio = (((totalStakedTmp * SCALE) / totalSharesTmp) /
                SCALE);
            return ((_amount * SCALE) / ratio) / SCALE;
        } else {
            uint256 ratio = (((totalSharesTmp * SCALE) / totalStakedTmp) /
                SCALE);
            return _amount * ratio;
        }
    }

    function getUserReward(
        bytes32 _pid,
        address _addr
    )
        private
        view
        returns (uint256 _rewardToken, uint256 _fee, uint256 _currentShares)
    {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 currentShares = sharesByAddress[_pid][_addr];
        uint256 reward = (currentShares * pool.totalStaked * SCALE) /
            (pool.totalShares * SCALE);
        uint256 fee = (reward * feePerc * SCALE) / (100 * SCALE);

        return (reward, fee, currentShares);
    }

    /**
        this function can be used to check the amount of tokens that the user will receive when the staker withdraws
     */
    function previewUnstakeReward(
        bytes32 _pid
    ) external view returns (uint256 _reward, uint256 _fee) {
        PoolInfo memory pool = poolInfo[_pid];

        (bool isActive, int256 rewardAmount, bool shouldCountReward) = oracle
            .getPool(_pid);

        if (shouldCountReward) {
            if (rewardAmount > 0) pool.totalStaked += uint256(rewardAmount);
            else if (rewardAmount < 0) {
                uint256 absRewardAmount = uint256(-rewardAmount);
                pool.totalStaked -= absRewardAmount;
            }
        }

        uint256 currentShares = sharesByAddress[_pid][_msgSender()];
        uint256 reward = (currentShares * pool.totalStaked * SCALE) /
            (pool.totalShares * SCALE);
        uint256 fee = (reward * feePerc * SCALE) / (100 * SCALE);
        reward -= fee;
        return (reward, fee);
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
