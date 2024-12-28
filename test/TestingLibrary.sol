// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

library TestingLibrary {
    function calculateTotalStaked(
        uint256[2] memory _amountsStaked,
        int256 _rewardAmount
    ) public pure returns (uint256) {
        uint256 totalStakedExpected = 0;

        for (uint256 i = 0; i < _amountsStaked.length; i++) {
            totalStakedExpected += _amountsStaked[i];
        }

        if (_rewardAmount > 0) {
            totalStakedExpected += uint256(_rewardAmount);
        } else {
            uint256 absReward = uint256(-_rewardAmount);
            if (totalStakedExpected >= absReward) {
                totalStakedExpected -= absReward;
            }
        }

        return totalStakedExpected;
    }

    function calculateExpectedShares(
        uint256 totalShares,
        uint256 totalStaked,
        uint256 amountStaked,
        uint256 initialShares,
        uint256 scale
    ) public pure returns (uint256 newShares, uint256 stakerShares) {
        // Case 1: First staker in the pool
        if (totalShares == 0) {
            newShares = initialShares / scale;
            stakerShares = newShares;
            return (newShares, stakerShares);
        }

        // Case 2: Subsequent stakers
        uint256 updatedTotalStaked = totalStaked + amountStaked;

        newShares =
            (((totalShares * scale) / totalStaked) * updatedTotalStaked) /
            scale;
        
        stakerShares = newShares - totalShares;

        return (newShares, stakerShares);
    }
}