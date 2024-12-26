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
        @notice The following suite of tests are for the general properties of the deposit function
        Write the general properties...
     */
    function testFuzz_DepositWithPositiveRewardAmount(
        uint256 _rewardAmount,
        uint256 _amountStaked
    ) public {
        vm.assume(_rewardAmount < 2200000 && _rewardAmount > 0);
        vm.assume(_amountStaked < 25000000000 && _amountStaked > 0);

        vm.prank(OWNER);
        bolt.mint(STAKER1, _amountStaked);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        vm.warp(2);
        oracle.updatePool(pid, int256(_rewardAmount), true);
        vm.prank(STAKER1);
        bolt.approve(address(stakingContract), _amountStaked);
        vm.prank(STAKER1);
        stakingContract.deposit(_amountStaked, pid);
        StakingContract.PoolInfo memory poolAfterDeposit = stakingContract
            .getPool(pid);
        assertEq(
            poolAfterDeposit.totalStaked,
            _rewardAmount + _amountStaked,
            "Total staked is wrong"
        );
    }

    function calculateShares(
        uint256 depositAmount,
        uint256 totalStaked,
        uint256 totalShares
    ) internal pure returns (uint256) {
        return (depositAmount * totalShares) / totalStaked;
    }

    function testFuzz_DepositWithMultipleStakers(
        int256 _rewardAmount,
        uint256 _amountStakedFirst,
        uint256 _amountStakedSecond
    ) public {
        /**
            Restrict some values accepted
         */
        vm.assume(
            _amountStakedFirst > 0 && _amountStakedFirst < 25_000_000_000
        );
        vm.assume(
            _rewardAmount > -int256(_amountStakedFirst) &&
                _rewardAmount < 2_200_000
        );
        vm.assume(
            _amountStakedSecond > 0 && _amountStakedSecond < 25_000_000_000
        );

        /**
            The stakers need some tokens to interact with the pool
         */
        vm.prank(OWNER);
        bolt.mint(STAKER1, _amountStakedFirst);
        vm.prank(OWNER);
        bolt.mint(STAKER2, _amountStakedSecond);

        // eStorm creates the pool
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);

        /**
            The stakers deposit their amount in the contract
         */
        vm.prank(STAKER1);
        bolt.approve(address(stakingContract), _amountStakedFirst);
        vm.prank(STAKER1);
        stakingContract.deposit(_amountStakedFirst, pid);

        oracle.updatePool(pid, _rewardAmount, true);

        vm.prank(STAKER2);
        bolt.approve(address(stakingContract), _amountStakedSecond);
        vm.prank(STAKER2);
        stakingContract.deposit(_amountStakedSecond, pid);

        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);

        if (_rewardAmount > 0) {
            uint256 totalStakedExpected = _amountStakedFirst +
                _amountStakedSecond +
                uint256(_rewardAmount);

            assertEq(
                pool.totalStaked,
                totalStakedExpected,
                "Total staked is wrong"
            );
        } else {
            // These checks are needed to avoid underflow in the test
            uint256 totalStakedExpected = _amountStakedFirst +
                _amountStakedSecond;
            uint256 absReward = uint256(-_rewardAmount);
            if (totalStakedExpected >= absReward) {
                totalStakedExpected -= absReward;
            }

            assertEq(
                pool.totalStaked,
                totalStakedExpected,
                "Total staked is wrong"
            );
        }
        uint256 expectedSharesStaker1 = stakingContract.INITIAL_SHARES() /
            stakingContract.SCALE();
        uint256 expectedSharesStaker2;
        uint256 rewardAdjustedStaked = _amountStakedFirst;

        if(_rewardAmount > 0) {
            rewardAdjustedStaked += uint256(_rewardAmount);
        } else {
            rewardAdjustedStaked -= uint256(-_rewardAmount);
        }

        if (_rewardAmount > 0) {
            uint256 totalStakedAfterReward = rewardAdjustedStaked;

            expectedSharesStaker2 =
                (expectedSharesStaker1 * _amountStakedSecond) /
                totalStakedAfterReward;
        } else {
            uint256 totalStakedAfterReward = rewardAdjustedStaked;
            uint256 totalStakedAfterSecond = totalStakedAfterReward +
                _amountStakedSecond;

            uint256 adjustedShares = (((pool.totalShares *
                stakingContract.SCALE()) / totalStakedAfterReward) *
                totalStakedAfterSecond) / stakingContract.SCALE();

            expectedSharesStaker2 = adjustedShares - pool.totalShares;
        }
    }

    function test_porcodio() public {
        int256 rewardAmount = 4209;
        uint256 aliceDeposit = 17716;
        uint256 bobDeposit = 191;

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

        oracle.updatePool(pid, rewardAmount, true);
        vm.prank(STAKER2);
        bolt.approve(address(stakingContract), bobDeposit);
        vm.prank(STAKER2);
        stakingContract.deposit(bobDeposit, pid);

        console.log("FLAG");
        assertEq(
            stakingContract.getPool(pid).totalStaked,
            aliceDeposit + bobDeposit + uint256(rewardAmount),
            "Total staked is wrong"
        );
        assertEq(true, true, "No trues");
    }

    function testCheckShares() public {
        // Initial deposits for all stakers
        uint256 aliceDeposit = 100;
        uint256 bobDeposit = 100;
        uint256 devFee = 30;
        uint256 charlieDeposit = 200;

        // Set up initial token balances for our stakers
        vm.prank(OWNER);
        bolt.mint(STAKER1, aliceDeposit);
        vm.prank(OWNER);
        bolt.mint(STAKER2, bobDeposit);
        vm.prank(OWNER);
        bolt.mint(STAKER3, charlieDeposit);

        // Create the staking pool
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);

        // --- Alice's Initial Deposit ---
        vm.prank(STAKER1);
        bolt.approve(address(stakingContract), aliceDeposit);
        vm.prank(STAKER1);
        stakingContract.deposit(aliceDeposit, pid);

        uint256 aliceExpectedShares = stakingContract.INITIAL_SHARES();

        assertEq(
            stakingContract.sharesByAddress(pid, STAKER1),
            aliceExpectedShares,
            "Alice should have received initial shares"
        );

        // --- Simulate Dev Fee Deduction ---
        oracle.updatePool(pid, -int256(devFee), true);

        // --- Bob's Deposit ---
        vm.prank(STAKER2);
        bolt.approve(address(stakingContract), bobDeposit);
        vm.prank(STAKER2);
        stakingContract.deposit(bobDeposit, pid);

        uint256 bobExpectedShares = 142857;
        assertEq(
            stakingContract.sharesByAddress(pid, STAKER2),
            bobExpectedShares,
            "Bob should have received the correct number of shares"
        );

        // --- Charlie's Deposit ---
        // When Charlie enters:
        // - Pool has 170 eBolt (100 - 30 + 100)
        // - Total shares are 242,857 (100,000 + 142,857)
        // - Charlie adds 200 eBolt
        // - New total is 370 eBolt
        // - Deposit ratio = 200/370 = 0.54054054...
        // - New total shares = 242,857 / (1 - 0.54054054) = 528,571
        // - Charlie's shares = 528,571 - 242,857 = 285,714
        vm.prank(STAKER3);
        bolt.approve(address(stakingContract), charlieDeposit);
        vm.prank(STAKER3);
        stakingContract.deposit(charlieDeposit, pid);

        uint256 charlieExpectedShares = 285714; // Corrected value based on exact calculation

        // Verify Charlie's shares
        assertEq(
            stakingContract.sharesByAddress(pid, STAKER3),
            charlieExpectedShares,
            "Charlie should have received the correct number of shares"
        );

        // Verify the total shares in the pool
        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);
        assertEq(
            pool.totalShares,
            aliceExpectedShares + bobExpectedShares + charlieExpectedShares,
            "Total shares should equal all stakers' shares"
        );

        // Verify the total staked amount
        assertEq(
            pool.totalStaked,
            aliceDeposit + bobDeposit + charlieDeposit - devFee,
            "Total staked should equal all deposits minus dev fee"
        );

        // Print all values for debugging and verification
        console.log("--- Final Pool State with Three Stakers ---");
        console.log(
            "Alice's shares:",
            stakingContract.sharesByAddress(pid, STAKER1)
        );
        console.log(
            "Bob's shares:",
            stakingContract.sharesByAddress(pid, STAKER2)
        );
        console.log(
            "Charlie's shares:",
            stakingContract.sharesByAddress(pid, STAKER3)
        );
        console.log("Total shares:", pool.totalShares);
        console.log("Total staked:", pool.totalStaked);

        // Calculate and verify share proportions
        uint256 aliceSharePercentage = (stakingContract.sharesByAddress(
            pid,
            STAKER1
        ) * 100) / pool.totalShares;
        uint256 bobSharePercentage = (stakingContract.sharesByAddress(
            pid,
            STAKER2
        ) * 100) / pool.totalShares;
        uint256 charlieSharePercentage = (stakingContract.sharesByAddress(
            pid,
            STAKER3
        ) * 100) / pool.totalShares;

        console.log("--- Share Percentages ---");
        console.log("Alice's share percentage:", aliceSharePercentage, "%");
        console.log("Bob's share percentage:", bobSharePercentage, "%");
        console.log("Charlie's share percentage:", charlieSharePercentage, "%");
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
