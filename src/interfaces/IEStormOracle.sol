// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IEStormOracle {
    event PoolUpdated(
        bytes32 pid,
        int256 dept,
        bool isActive,
        uint256 lastDeptUpdate
    );

    function updatePool(bytes32 _pid, int256 _dept, bool _isActive) external;
    function lockPool(bytes32 _pid) external;
}
