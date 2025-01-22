// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Bolt} from "../src/Bolt.sol";
import {StakingContract} from "../src/StakingContract.sol";
import {EStormOracle} from "../src/EStormOracle.sol";
import {console} from "forge-std/console.sol";
import {TestingLibrary} from "./TestingLibrary.sol";

contract DepositTest is Test {
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
            _amountStakedFirst > 0 && _amountStakedFirst < 5_000_000_000_000_000
        );
        vm.assume(
            _rewardAmount > -int256(_amountStakedFirst) &&
                _rewardAmount < 2_200_000_000
        );
        vm.assume(
            _amountStakedSecond > 0 &&
                _amountStakedSecond < 5_000_000_000_000_000
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

        if (_rewardAmount < 0) {
            assertEq(
                _amountStakedFirst +
                    _amountStakedSecond -
                    uint256(-_rewardAmount),
                pool.totalStaked,
                "Total staked is wrong"
            );
        } else {
            assertEq(
                _amountStakedFirst +
                    _amountStakedSecond +
                    uint256(_rewardAmount),
                pool.totalStaked,
                "Total staked is wrong"
            );
        }

        assertEq(
            stakingContract.sharesByAddress(pid, STAKER1),
            _amountStakedFirst * 10 ** bolt.decimals(),
            "There must be at least X  shares"
        );
        
        assertEq(
            pool.totalShares - stakingContract.sharesByAddress(pid, STAKER1),
            stakingContract.sharesByAddress(pid, STAKER2),
            "STAKER2 shares wrong"
        );
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
