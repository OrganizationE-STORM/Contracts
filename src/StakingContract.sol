// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {EStormOracle} from "./EStormOracle.sol";
import {EBolt} from "./EBolt.sol";
import {console} from "forge-std/console.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IStakingContract} from "./interfaces/IStakingContract.sol";

contract StakingContract is IStakingContract, Ownable {
    using Math for uint256;

    mapping(bytes32 => PoolInfo) public poolInfo; // the key is obtained by concatenating the _gameID, _challengeID and the _userID
    mapping(string => bool) public gamesRegistered;
    mapping(string => bool) public usersRegistered;
    mapping(bytes32 => mapping(address => uint256)) public sharesByAddress;

    uint16 public feePerc = 2000;

    address public treasury;
    EStormOracle public oracle;
    EBolt public immutable eBolt;

    constructor(
        EBolt _bolt,
        EStormOracle _oracle,
        address _treasury
    ) Ownable(_msgSender()) {
        eBolt = _bolt;
        oracle = _oracle;
        treasury = _treasury;
    }

    /*
     * @dev Creates a new pool by generating a pid.
     *
     * Emits a {PoolCreated} event.
     *
     * Requirements:
     *
     * - the caller must be the owner
     */
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

    /*
     * @dev Deposits eBolts in the pool.
     *
     * Whenever is called, the value returned by the oracle is added to {totalStaked}
     * before assigning new shares.
     *
     * Emits a {Deposit} event.
     *
     * Requirements:
     *
     * - the amount cannot be zero
     * - the oracle must be active
     */
    function deposit(uint256 _amount, bytes32 _pid) external {
        require(_amount > 1_000_000, "Amount cannot be less than 1M");

        (bool isActive, int256 debt, bool shouldUpdateDept) = oracle.getPool(
            _pid
        );
        require(isActive, "Pool not active");

        uint256 shares = previewDeposit(_amount, _pid);
        if (shouldUpdateDept) updateDept(debt, _pid);

        PoolInfo storage pool = poolInfo[_pid];
        pool.totalStaked += _amount;
        pool.totalShares += shares;
        sharesByAddress[_pid][_msgSender()] += shares;

        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(eBolt, _msgSender(), address(this), _amount);
        emit Deposit(_msgSender(), _amount, _pid);
    }

    /*
     * @dev Withdraws eBolts from the pool.
     *
     * Whenever is called, the value returned by the oracle is added to {totalStaked}
     * before withdrawing funds.
     *
     * A fee in eBolts is applied to the amount and sent to {devaddr}
     *
     * Emits a {Withdraw} event.
     *
     * Requirements:
     *
     * - the amount cannot be zero
     * - (the oracle must be active to withdraw)
     * - (the amount cannot be greater than the funds owned by the caller)
     */
    function withdraw(bytes32 _pid, uint256 _amount) external {
        require(_amount > 0, "Amount not value");
        (, int256 debtAmount, bool shouldUpdateDept) = oracle.getPool(_pid);

        uint256 shares = _previewWithdraw(_amount, _pid);
        uint256 fee = previewFee(_amount);
        uint256 assets = convertToAssets(shares, _pid);

        if (shouldUpdateDept) updateDept(debtAmount, _pid);

        PoolInfo storage pool = poolInfo[_pid];

        if (assets > pool.totalStaked) assets = pool.totalStaked;

        pool.totalStaked -= assets;
        pool.totalShares -= shares;
        sharesByAddress[_pid][_msgSender()] -= shares;
        assets -= fee;

        SafeERC20.safeTransfer(eBolt, treasury, fee);
        SafeERC20.safeTransfer(eBolt, _msgSender(), assets);

        emit Withdraw(_msgSender(), assets, fee, _pid);
    }

    /*
     * @dev See {_convertToAssets}.
     */
    function convertToAssets(
        uint256 _shares,
        bytes32 _pid
    ) public view returns (uint256) {
        return _convertToAssets(_shares, _pid);
    }

    /*
     * @dev Returns the funds that correspond to a given amount of shares in a pool if
     * the value returned by the oracle would be added to {totalStaked}.
     *
     * funds = shares * ({totalStaked} + 1) / ({totalShares} + 10 ** {eBolt-decimals})
     *
     * Uses {Math-mulDiv} for the formula.
     *
     * NOTE: {totalStaked} is not actually updated.
     */
    function _convertToAssets(
        uint256 _shares,
        bytes32 _pid
    ) private view returns (uint256) {
        (, int256 debtAmount, ) = oracle.getPool(_pid);

        PoolInfo memory pool = poolInfo[_pid];
        uint256 tokens = pool.totalStaked;

        if (debtAmount < 0) tokens -= uint256(-debtAmount);
        else tokens += uint256(debtAmount);

        return
            _shares.mulDiv(
                tokens + 1,
                pool.totalShares + 10 ** eBolt.decimals(),
                Math.Rounding.Ceil
            );
    }

    /*
     * @dev See {_convertToShares}.
     */
    function convertToShares(
        uint256 _amount,
        bytes32 _pid,
        Math.Rounding _rounding
    ) external view returns (uint256) {
        return _convertToShares(_amount, _pid, _rounding);
    }

    /*
     * @dev Returns the shares that correspond to a given amount of funds in a pool if
     * the value returned by the oracle would be added to {totalStaked}.
     *
     * shares = funds * ({totalShares} + 10 ** {eBolt-decimals}) / ({totalStaked} + 1)
     *
     * Uses {Math-mulDiv} for the formula.
     *
     * NOTE: {totalStaked} is not actually updated.
     */
    function _convertToShares(
        uint256 _amount,
        bytes32 _pid,
        Math.Rounding _rounding
    ) private view returns (uint256) {
        (, int256 debtAmount, ) = oracle.getPool(_pid);

        PoolInfo memory pool = poolInfo[_pid];
        uint256 tokens = pool.totalStaked;

        if (debtAmount < 0) tokens -= uint256(-debtAmount);
        else tokens += uint256(debtAmount);

        return
            _amount.mulDiv(
                pool.totalShares + 10 ** eBolt.decimals(),
                tokens + 1,
                _rounding
            );
    }

    /*
     * @dev See {_previewWithdraw}.
     */
    function previewWithdraw(
        uint256 _amount,
        bytes32 _pid
    ) external view returns (uint256) {
        return _previewWithdraw(_amount, _pid);
    }

    /*
     * @dev Returns the same value as {_convertToShares} but if it is greater than
     * the total shares owned by the caller in the pool it is set to this value instead.
     *
     * It helps to avoid rounding errors while withdrawing all the funds.
     */
    function _previewWithdraw(
        uint256 _amount,
        bytes32 _pid
    ) private view returns (uint256) {
        uint256 shares = _convertToShares(_amount, _pid, Math.Rounding.Ceil);

        if (shares > sharesByAddress[_pid][_msgSender()]) {
            console.log("Triggered");
            shares = sharesByAddress[_pid][_msgSender()];
        }

        return shares;
    }

    function updateDept(int256 _debtAmount, bytes32 _pid) private {
        PoolInfo storage pool = poolInfo[_pid];
        if (_debtAmount > 0) {
            pool.totalStaked += uint256(_debtAmount);
            SafeERC20.safeTransferFrom(
                eBolt,
                treasury,
                address(this),
                uint256(_debtAmount)
            );
        } else if (_debtAmount < 0) {
            uint256 absdebtAmount = uint256(-_debtAmount);
            require(
                pool.totalStaked >= absdebtAmount,
                "Dept amount value not valid"
            );
            pool.totalStaked -= absdebtAmount;
            SafeERC20.safeTransfer(eBolt, treasury, absdebtAmount);
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
        return _amount.mulDiv(feePerc, 100_000, Math.Rounding.Ceil);
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

    function setDevFee(uint16 _newFee) external onlyOwner {
        feePerc = _newFee;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }
}
