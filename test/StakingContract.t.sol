// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Bolt} from "../src/Bolt.sol";
import {StakingContract} from "../src/StakingContract.sol";
import {EStormOracle} from "../src/EStormOracle.sol";
import {console} from "forge-std/console.sol";
import {TestingLibrary} from "./TestingLibrary.sol";

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

    function testFuzz_DepositWithMultipleStakers(
        int256 _rewardAmount,
        uint256 _amountStakedFirst,
        uint256 _amountStakedSecond
    ) public {
        //build
        vm.assume(
            _amountStakedFirst > 0 && _amountStakedFirst < 5_000_000_000_000
        );
        vm.assume(
            _rewardAmount > -int256(_amountStakedFirst) &&
                _rewardAmount < 2_200_000
        );
        vm.assume(
            _amountStakedSecond > 0 && _amountStakedSecond < 5_000_000_000_000
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

        uint256 totalStakedExpected = TestingLibrary.calculateTotalStaked(
            [_amountStakedFirst, _amountStakedSecond],
            _rewardAmount
        );

        (uint256 totalShares2, uint256 stakerShares2) = TestingLibrary
            .calculateExpectedShares(
                100_000,
                pool.totalStaked - _amountStakedSecond, // Subtract STAKER2's stake to get previous staking
                _amountStakedSecond,
                stakingContract.INITIAL_SHARES(),
                stakingContract.SCALE()
            );

        assertEq(
            totalStakedExpected,
            pool.totalStaked,
            "Total staked is wrong"
        );
        assertEq(totalShares2, pool.totalShares, "Total shares wrong");
        assertEq(
            stakingContract.sharesByAddress(pid, STAKER1),
            100_000,
            "There must be at least 100_000 shares"
        );
        assertEq(
            stakerShares2,
            stakingContract.sharesByAddress(pid, STAKER2),
            "STAKER2 shares wrong"
        );
    }

    function testFuzz_withdrawIsCorrect(
        int256 _rewardFromOracle,
        uint256 _amountStaker1,
        uint256 _amountStaker2,
        uint256 _amountStaker3
    ) public {
         vm.assume(
            _amountStaker1 > 0 && _amountStaker1 < 5_000_000_000_000
        );
        vm.assume(
            _rewardFromOracle > 0 &&
                _rewardFromOracle < 2_200_000
        );
        vm.assume(
            _amountStaker2 > 0 && _amountStaker2 < 5_000_000_000_000
        );
        vm.assume(
            _amountStaker3 > 0 && _amountStaker3 < 5_000_000_000_000
        );

        uint256 devAddrBalanceBefore = bolt.balanceOf(DEVADDR);
        mint(STAKER1, _amountStaker1);
        mint(STAKER2, _amountStaker2);
        mint(STAKER3, _amountStaker3);

        vm.assume(_rewardFromOracle > 0);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);

        stakeToken(STAKER1, _amountStaker1);
        stakeToken(STAKER2, _amountStaker2);
        stakeToken(STAKER3, _amountStaker3);

        oracle.updatePool(pid, _rewardFromOracle, true);

        vm.prank(STAKER3);
        (uint256 reward, uint256 fee) = stakingContract.previewUnstakeReward(pid);

        assertEq(fee > 0, true, "Reward amount is less than before");
        assertEq()
    }

    function mint(address _receiver, uint256 _amount) private {
        vm.prank(OWNER);
        bolt.mint(_receiver, _amount);
    }

    function stakeToken(address _staker, uint256 _amount) private {
        vm.prank(_staker);
        bolt.approve(address(stakingContract), _amount);
        vm.prank(_staker);
        stakingContract.deposit(_amount, pid);
    }

    function test_porcodio() public {
        int256 rewardAmount = 0;
        uint256 aliceDeposit = 100;
        uint256 bobDeposit = 2000;

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

        (uint256 totalShares1, uint256 stakerShares1) = TestingLibrary
            .calculateExpectedShares(
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

        (uint256 totalShares2, uint256 stakerShares2) = TestingLibrary
            .calculateExpectedShares(
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

        vm.prank(STAKER1);
        stakingContract.withdraw(pid);

        assertEq(
            stakingContract.getPool(pid).totalStaked,
            bobDeposit,
            "Tokens not updated"
        );
        assertEq(
            stakingContract.getPool(pid).totalShares,
            stakerShares2,
            "Shares wrong"
        );

        assertEq(bolt.balanceOf(STAKER1), 98, "ALICE balance wrong");
        assertEq(bolt.balanceOf(DEVADDR), 2, "DEVADDRESS balance wrong");
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

    function testFail_CreateMoreTokensThanPossible() public {
        bolt = new Bolt(OWNER);
        bolt.mint(OWNER, 1e40);
    }
}
