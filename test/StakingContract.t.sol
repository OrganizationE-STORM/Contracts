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

    function testFuzz_DepositWithMultipleStakers(
        int256 _rewardAmount,
        uint256 _amountStakedFirst,
        uint256 _amountStakedSecond
    ) public {
        /**
            Restrict some values accepted
         */
        vm.assume(_rewardAmount > -2_200_000 && _rewardAmount < 2_200_000);
        vm.assume(
            _amountStakedFirst > 0 && _amountStakedFirst < 25_000_000_000
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
        oracle.updatePool(pid, _rewardAmount, true);

        /**
            The stakers deposit their amount in the contract
         */
        vm.prank(STAKER1);
        bolt.approve(address(stakingContract), _amountStakedFirst);
        vm.prank(STAKER1);
        stakingContract.deposit(_amountStakedFirst, pid);

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
            if (
                totalStakedExpected >= absReward
            ) {
                totalStakedExpected -= absReward;
            }

            assertEq(
                pool.totalStaked,
                totalStakedExpected,
                "Total staked is wrong"
            );
        }
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
