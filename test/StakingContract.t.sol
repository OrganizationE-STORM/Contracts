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
        stakingContract = new StakingContract(address(bolt), oracle);
        stakingContract.addGame(GAME);
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
    function testStakerDeposit() public {
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

        StakingContract.PoolInfo memory poolAfterDeposit = stakingContract.getPool(pid);

        assertEq(poolAfterDeposit.totalStaked, amountStaked, "Total staked mismatch after deposit");
        assertEq(poolAfterDeposit.totalShares > 0, true, "Total shares should increase after deposit");
        assertEq(poolAfterDeposit.lastRewardUpdate, block.timestamp, "Last reward update timestamp mismatch");
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
