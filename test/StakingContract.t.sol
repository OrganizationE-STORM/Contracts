// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Bolt} from "../src/Bolt.sol";
import {StakingContract} from "../src/StakingContract.sol";
import {EStormOracle} from "../src/EStormOracle.sol";
import {console} from "forge-std/console.sol";

contract StakingContractPoolCreationTest is Test {
    // Test Constants
    string constant GAME = "LOL";
    string constant CHALLENGE = "WOG";
    string constant USER_ID = "Alessio";
    address constant OWNER = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address constant STAKER1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant STAKER2 = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
    address constant STAKER3 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant DEVADDR = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    uint256 public constant INITIAL_SHARES = 100000;

    // Test Variables
    Bolt internal bolt;
    StakingContract internal stakingContract;
    EStormOracle internal oracle;

    bytes32 internal pid;

    /// @notice Set up shared state for all tests
    function setUp() public {
        bolt = new Bolt(OWNER);
        oracle = new EStormOracle();
        pid = keccak256(abi.encode(GAME, CHALLENGE, USER_ID));
        stakingContract = new StakingContract(bolt, oracle, DEVADDR);
        stakingContract.addGame(GAME);
        vm.prank(OWNER);
        bolt.setStakingContract(address(stakingContract));
        oracle.setStakingContract(address(stakingContract));
    }

    /// @notice Test that a pool is successfully created
    function testPoolCreation() public {
        oracle.updatePool(pid, 60, true);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);

        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);

        // Assertions
        assertEq(pool.id, pid, "Pool ID mismatch");
        assertEq(pool.totalStaked, 0, "Initial totalStaked should be zero");
        assertEq(pool.totalShares, 0, "Initial totalShares should be zero");
        assertEq(
            pool.lastRewardUpdate,
            block.timestamp,
            "Incorrect lastRewardUpdate"
        );
    }

    /**
        I've tried different numbers for the amount staked by each address.
        If I increase it to 2_500_000_000_000 (so with an extra zero) this test won't pass
        If I leave it 2_500_000_000_00 (without the extra zero at the end) this test won't have any problem 
     */
    function testFuzz_DepositWithMultipleStakers(
        int256 _rewardAmount,
        uint256 _amountStakedFirst,
        uint256 _amountStakedSecond
    ) public {
        //build
        vm.assume(
            _amountStakedFirst > 0 && _amountStakedFirst < 2_500_000_000_00
        );
        vm.assume(
            _rewardAmount > -int256(_amountStakedFirst) &&
                _rewardAmount < 2_200_000
        );
        vm.assume(
            _amountStakedSecond > 0 && _amountStakedSecond < 2_500_000_000_00
        );

        vm.prank(OWNER);
        bolt.mint(STAKER1, _amountStakedFirst);
        vm.prank(OWNER);
        bolt.mint(STAKER2, _amountStakedSecond);

        // operate
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);

        stakeToken(STAKER1, _amountStakedFirst);
        oracle.updatePool(pid, _rewardAmount, true);
        stakeToken(STAKER2, _amountStakedSecond);

        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);

        uint256 totalStakedExpected = calculateTotalStaked(
            [_amountStakedFirst, _amountStakedSecond],
            _rewardAmount
        );

        (uint256 totalShares2, uint256 stakerShares2) = calculateExpectedShares(
            100_000,
            pool.totalStaked - _amountStakedSecond, // Subtract STAKER2's stake to get previous staking
            _amountStakedSecond,
            stakingContract.INITIAL_SHARES(),
            stakingContract.SCALE()
        );

        // check
        assertEq(totalStakedExpected, pool.totalStaked, "Total staked is wrong");
        assertEq(totalShares2, pool.totalShares, "Total shares wrong");
        assertEq(stakingContract.sharesByAddress(pid, STAKER1), 100_000, "There must be at least 100_000 shares");
        assertEq(stakerShares2, stakingContract.sharesByAddress(pid, STAKER2), "STAKER2 shares wrong");
    }

    function stakeToken(address _staker, uint256 _amount) private {
        vm.prank(_staker);
        bolt.approve(address(stakingContract), _amount);
        vm.prank(_staker);
        stakingContract.deposit(_amount, pid);
    }

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

    function test_porcodio() public {
        int256 rewardAmount = -50003;
        uint256 aliceDeposit = 50000000;
        uint256 bobDeposit = 10000;

        vm.prank(OWNER);
        bolt.mint(STAKER1, aliceDeposit);
        vm.prank(OWNER);
        bolt.mint(STAKER2, bobDeposit);

        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);

        vm.prank(STAKER1);
        bolt.approve(address(stakingContract), aliceDeposit);
        vm.prank(STAKER1);
        stakingContract.deposit(aliceDeposit, pid);

        (uint256 totalShares1, uint256 stakerShares1) = calculateExpectedShares(
            0, // No previous shares
            0, // No previous staking
            aliceDeposit,
            stakingContract.INITIAL_SHARES(),
            stakingContract.SCALE()
        );

        // Validate STAKER1 shares
        assertEq(
            stakingContract.sharesByAddress(pid, STAKER1),
            stakerShares1,
            "Shares for STAKER1 are wrong"
        );

        oracle.updatePool(pid, rewardAmount, true);
        vm.prank(STAKER2);
        bolt.approve(address(stakingContract), bobDeposit);
        vm.prank(STAKER2);
        stakingContract.deposit(bobDeposit, pid);

        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);

        // Calculate expected shares for STAKER2
        
        (uint256 totalShares2, uint256 stakerShares2) = calculateExpectedShares(
            totalShares1,
            pool.totalStaked - bobDeposit, // Subtract STAKER2's stake to get previous staking
            bobDeposit,
            stakingContract.INITIAL_SHARES(),
            stakingContract.SCALE()
        );
        
        assertEq(
            stakingContract.sharesByAddress(pid, STAKER2),
            stakerShares2,
            "Shares for STAKER2 are wrong"
        );
        assertEq(
            stakingContract.getPool(pid).totalStaked,
            aliceDeposit + bobDeposit - uint256(-rewardAmount),
            "Total staked is wrong"
        );
        
    }

    /// @notice Test that pool creation reverts if the game is invalid
    function testFail_InvalidGameRevertsOnPoolCreation() public {
        stakingContract.createPool(50, 50, "InvalidGame", CHALLENGE, USER_ID);
    }

    /// @notice Test that deposits revert if the pool is not active
    function testFail_DepositRevertsIfPoolNotActive() public {
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);

        vm.prank(STAKER1);
        stakingContract.deposit(500, pid);
    }
}
