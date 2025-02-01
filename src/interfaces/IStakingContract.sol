// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IStakingContract {
    struct PoolInfo {
        bytes32 id;
        string userID;
        uint256 totalStaked;
        uint256 totalShares;
    }
     
    event PoolCreated(
        string gameID,
        string challengeID,
        string userID,
        bytes32 pid
    );
    event DevFeeUpdated(uint256 oldFee, uint256 newFee);

    event Deposit(address staker, uint256 amount, bytes32 pid);
    event Withdraw(address staker, uint256 amount, uint256 fee, bytes32 pid);

    function createPool(
        string memory _gameID,
        string memory _challengeID,
        string memory _userID
    ) external;

    function deposit(uint256 _amount, bytes32 _pid) external;
    function withdraw(bytes32 _pid, uint256 _amount) external;

    function convertToAssets(
        uint256 _shares,
        bytes32 _pid
    ) external view returns (uint256);

    function convertToShares(
        uint256 _amount,
        bytes32 _pid,
        Math.Rounding _rounding
    ) external view returns (uint256);

    function previewWithdraw(
        uint256 _amount,
        bytes32 _pid
    ) external view returns (uint256);

    function previewDeposit(
        uint256 _amount,
        bytes32 _pid
    ) external view returns (uint256);

    function getPool(bytes32 _pid) external view returns(PoolInfo memory);
}
