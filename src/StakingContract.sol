// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {EStormOracle} from "./EStormOracle.sol";
import {Bolt} from "./Bolt.sol";
import {console} from "forge-std/console.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IStakingContract} from "./interfaces/IStakingContract.sol";

contract StakingContract is IStakingContract, Pausable, Ownable {
    using Math for uint256;
    
    struct PoolInfo {
        bytes32 id;
        string userID;
        uint256 totalStaked;
        uint256 totalShares;
    }

    mapping(bytes32 => PoolInfo) public poolInfo; // the key is obtained by concatenating the _gameID, _challengeID and the _userID
    mapping(string => bool) public gamesRegistered;
    mapping(string => bool) public usersRegistered;
    mapping(bytes32 => mapping(address => uint256)) public sharesByAddress;

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
        string memory _gameID,
        string memory _challengeID,
        string memory _userID
    ) external onlyOwner {
        require(gamesRegistered[_gameID], "Game not registered");

        if (!usersRegistered[_userID]) usersRegistered[_userID] = true;

        bytes32 pid = keccak256(abi.encode(_gameID, _challengeID, _userID));
        require(poolInfo[pid].id != pid, "Pool already registered");

        poolInfo[pid] = PoolInfo({
            id: pid,
            userID: _userID,
            totalStaked: 0,
            totalShares: 0
        });

        emit PoolCreated(_gameID, _challengeID, _userID, pid);
    }

    function deposit(uint256 _amount, bytes32 _pid) external {
        require(_amount > 0, "Amount cannot be zero");

        (bool isActive, int256 dept, bool shouldUpdateDept) = oracle.getPool(
            _pid
        );
        require(isActive, "Pool not active");

        uint256 shares = previewDeposit(_amount, _pid);
        if (shouldUpdateDept) updateDept(dept, _pid);

        PoolInfo storage pool = poolInfo[_pid];
        pool.totalStaked += _amount;
        pool.totalShares += shares;
        sharesByAddress[_pid][_msgSender()] += shares;

        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(bolt, _msgSender(), address(this), _amount);
        emit Deposit(_msgSender(), _amount, _pid);
    }

    function withdraw(bytes32 _pid, uint256 _amount) public {
        require(_amount > 0, "Amount not value");
        (bool isActive, int256 deptAmount, bool shouldUpdateDept) = oracle
            .getPool(_pid);
        require(isActive, "Pool not active");

        uint256 shares = _previewWithdraw(_amount, _pid);
        uint256 fee = previewFee(_amount);
        require(
            shares <= sharesByAddress[_pid][_msgSender()],
            "Shares amount not valid"
        );

        if (shouldUpdateDept) updateDept(deptAmount, _pid);

        PoolInfo storage pool = poolInfo[_pid];
        pool.totalStaked -= _amount;
        pool.totalShares -= shares;
        sharesByAddress[_pid][_msgSender()] -= shares;
        _amount -= fee;

        SafeERC20.safeTransfer(bolt, devaddr, fee);
        SafeERC20.safeTransfer(bolt, _msgSender(), _amount);

        emit Withdraw(_msgSender(), _amount, fee, _pid);
    }

    function convertToAssets(
        uint256 _shares,
        bytes32 _pid
    ) public view returns (uint256) {
        (, int256 deptAmount, ) = oracle.getPool(_pid);

        PoolInfo memory pool = poolInfo[_pid];
        uint256 tokens = pool.totalStaked;

        if (deptAmount < 0) tokens -= uint256(-deptAmount);
        else tokens += uint256(deptAmount);

        return
            _shares.mulDiv(
                tokens + 1,
                pool.totalShares + 10 ** bolt.decimals(),
                Math.Rounding.Ceil
            );
    }

    function convertToShares(
        uint256 _amount,
        bytes32 _pid,
        Math.Rounding _rounding
    ) external view returns (uint256) {
        return _convertToShares(_amount, _pid, _rounding);
    }

    function _convertToShares(
        uint256 _amount,
        bytes32 _pid,
        Math.Rounding _rounding
    ) private view returns (uint256) {
        (, int256 deptAmount, ) = oracle.getPool(_pid);

        PoolInfo memory pool = poolInfo[_pid];
        uint256 tokens = pool.totalStaked;

        if (deptAmount < 0) tokens -= uint256(-deptAmount);
        else tokens += uint256(deptAmount);

        return
            _amount.mulDiv(
                pool.totalShares + 10 ** bolt.decimals(),
                tokens + 1,
                _rounding
            );
    }

    function previewWithdraw(
        uint256 _amount,
        bytes32 _pid
    ) external view returns (uint256) {
        return _previewWithdraw(_amount, _pid);
    }

    function _previewWithdraw(
        uint256 _amount,
        bytes32 _pid
    ) private view returns (uint256) {
        uint256 shares = _convertToShares(_amount, _pid, Math.Rounding.Ceil);

        if (shares > sharesByAddress[_pid][_msgSender()])
            shares = sharesByAddress[_pid][_msgSender()];

        return shares;
    }

    //TODO: add the check on the total supply if _deptAmount is positive
    function updateDept(int256 _deptAmount, bytes32 _pid) private {
        PoolInfo storage pool = poolInfo[_pid];
        if (_deptAmount > 0) {
            pool.totalStaked += uint256(_deptAmount);
            safeEBoltTransfer(address(this), uint256(_deptAmount));
        } else if (_deptAmount < 0) {
            uint256 absdeptAmount = uint256(-_deptAmount);
            require(
                pool.totalStaked >= absdeptAmount,
                "Dept amount value not valid"
            );
            pool.totalStaked -= absdeptAmount;
            safeEBoltTransfer(devaddr, absdeptAmount);
        }
        oracle.lockPool(_pid);
    }

    function previewDeposit(
        uint256 _amount,
        bytes32 _pid
    ) public view returns (uint256) {
        return _convertToShares(_amount, _pid, Math.Rounding.Floor);
    }

    function previewFee(uint256 _amount) public view returns (uint256) {
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
