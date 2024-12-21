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
    address constant DEVADDR = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
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
        assertEq(pool.lastRewardUpdate, block.timestamp, "Incorrect lastRewardUpdate");
    }

    /// @notice Test that a staker can deposit tokens into a pool
    function testStakerDepositWithNoRewards() public {
        uint256 amountStaked = 500;

        // Transfer tokens to staker
        bolt.transfer(STAKER1, amountStaked);

        // eStorm creates the pool for the user
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);

        vm.warp(10);
        
        // eStorm enables the challenge
        oracle.updatePool(pid, 0, true);
        
        vm.prank(STAKER1);
        stakingContract.deposit(amountStaked, pid);
        vm.prank(STAKER2);
        stakingContract.deposit(amountStaked + 100, pid);

        StakingContract.PoolInfo memory poolAfterDeposit = stakingContract.getPool(pid);
        uint256 staker1Shares = stakingContract.sharesByAddress(pid, STAKER1);
        uint256 staker2Shares = stakingContract.sharesByAddress(pid, STAKER2);

        assertEq(poolAfterDeposit.totalStaked, amountStaked + amountStaked + 100, "Total staked mismatch after deposit");
        assertEq(staker1Shares, INITIAL_SHARES, "Staker 1 shares are wrong");
        assertEq(staker2Shares, 120000,"Staker 2 shares are wrong");
    }
    
    /// @notice Testing deposit with a rewardAmount > 0
    function testStakerDepositWithPositiveReward() public {
        uint256 amountStaked = 500;
        uint256 rewardAmount = 60;
        bolt.transfer(STAKER1, amountStaked);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        vm.warp(10);
        oracle.updatePool(pid, int256(rewardAmount), true);
        vm.prank(STAKER1);
        stakingContract.deposit(amountStaked, pid);
        StakingContract.PoolInfo memory poolAfterDeposit = stakingContract.getPool(pid);
        assertEq(poolAfterDeposit.totalStaked, amountStaked + 60, "Total staked is wrong"); 
        assertEq(bolt.balanceOf(address(stakingContract)), rewardAmount, "Balance wrong");
    }

    /// @notice Testing deposit with a reward < 0
    function testStakerDepositWithNegativeReward() public {
        uint256 amountStaked = 500;
        int256 rewardAmount = -60;
        uint256 absRewardAmount = uint256(-rewardAmount);
        bolt.transfer(STAKER1, amountStaked);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        vm.warp(2);                     
        oracle.updatePool(pid, 0, true); // the challenge opens for the first time
        vm.prank(STAKER1);
        stakingContract.deposit(amountStaked, pid); // a user deposits
        oracle.updatePool(pid, 0, false); // the challenge closes 
        vm.warp(10); 
        oracle.updatePool(pid, rewardAmount, true); // the challenge finishes
        vm.prank(STAKER1);
        stakingContract.deposit(amountStaked, pid); // a user deposits
        StakingContract.PoolInfo memory poolAfterDeposit = stakingContract.getPool(pid);
        assertEq(poolAfterDeposit.totalStaked, amountStaked * 2 - absRewardAmount, "Total stake amount is wrong");
        assertEq(bolt.balanceOf(DEVADDR), absRewardAmount, "Balance wrong");
    }

    /**
        @notice The following suite of tests are for the general properties of the deposit function
        Write the general properties...
     */
    function testFuzz_DepositWithPositiveRewardAmount(uint256 _rewardAmount, uint256 _amountStaked) public {
        vm.assume(_rewardAmount < 2200000 && _rewardAmount > 0);
        vm.assume(_amountStaked < 25000000000 && _amountStaked > 0);
        bolt.transfer(STAKER1, _amountStaked);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        vm.warp(2);                     
        oracle.updatePool(pid, int256(_rewardAmount), true);
        vm.prank(STAKER1);
        stakingContract.deposit(_amountStaked, pid);
        StakingContract.PoolInfo memory poolAfterDeposit = stakingContract.getPool(pid);
        assertEq(poolAfterDeposit.totalStaked, _rewardAmount + _amountStaked, "Total staked is wrong");
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
