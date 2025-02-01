// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEStormOracle} from "./interfaces/IEStormOracle.sol";
import {IStakingContract} from "./interfaces/IStakingContract.sol";

/**
 * @dev Implementation of the {IEStormOracle} interface.
 *
 * EStormOracle's implementations allow eStorm to keep the network updated about
 * gamers' performance on games played with the eStorm Client.
 *
 * This implementation updates each pool with a value called {debt}, which can be
 * positive or negative, that reflects the collective gains/losses of a staking
 * pool for sponsoring the challenges of a player. {debt} reflects the one available
 * on the eStorm Client.
 *
 * Each pool is represented by a unique id and has the following attributes:
 *
 * - {isActive}: boolean value that shows if the gamer is asking for sponsorship
 * on that pool
 *
 * - {debt}: int value that represents the gains/losses made by the staking pool
 *
 * - {shouldCountDept}: boolean value that shows if the staking pool should add up
 * the current {debt} in its balance.
 *
 */

contract EStormOracle is IEStormOracle, Ownable {
    struct PoolInfo {
        bool isActive;
        int256 debt;
        bool shouldCountDept;
    }

    mapping(bytes32 => PoolInfo) public infoByPID;

    address public stakingContract;

    constructor() Ownable(_msgSender()) {}

    /*
     * @dev Updates {debt} and {isActive} status of a given pool.
     *
     * {shouldCountDept} is set to True.
     *
     * Emits a {PoolUpdated} event.
     *
     * Requirements:
     *
     * - the caller must be owner
     */
    function updatePool(
        bytes32 _pid,
        int256 _debt,
        bool _isActive
    ) external onlyOwner {
        if (_debt < 0) {
            IStakingContract stakingContractImpl = IStakingContract(
                stakingContract
            );
            uint256 debtAbs = uint256(-_debt);
            require(
                debtAbs <= stakingContractImpl.getPool(_pid).totalStaked,
                "Debt cannot be > totalStaked"
            );
        }

        infoByPID[_pid].isActive = _isActive;
        infoByPID[_pid].debt = _debt;
        infoByPID[_pid].shouldCountDept = true;
        emit PoolUpdated(_pid, _debt, _isActive, block.timestamp);
    }

    /*
     * @dev Sets {debt} to zero and updates {shouldCountDept} to False of a given pool.
     *
     * It should be called every time the staking contract updates the balance of a
     * staking pool. See {StakingContract-deposit} and {StakingContract-withdraw}.
     *
     * Requirements:
     *
     * - the caller must be the staking contract.
     */
    function lockPool(bytes32 _pid) external {
        require(msg.sender == stakingContract);
        infoByPID[_pid].shouldCountDept = false;
        infoByPID[_pid].debt = 0;
    }

    /*
     * @dev Updates {stakingContract} adrress.
     *
     * Requirements:
     *
     * - the caller must be the owner
     */
    function setStakingContract(address _addr) external onlyOwner {
        stakingContract = _addr;
    }

    /*
     * @dev Returns oracle's current state of a given pool
     */
    function getPool(bytes32 _pid) external view returns (bool, int256, bool) {
        return (
            infoByPID[_pid].isActive,
            infoByPID[_pid].debt,
            infoByPID[_pid].shouldCountDept
        );
    }
}
