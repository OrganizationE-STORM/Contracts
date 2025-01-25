// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Bolt} from "../src/Bolt.sol";
import {StakingContract} from "../src/StakingContract.sol";
import {EStormOracle} from "../src/EStormOracle.sol";
import {console} from "forge-std/console.sol";

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
    address constant SIGNER = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;

    // Test Variables
    Bolt internal bolt;
    StakingContract internal stakingContract;
    EStormOracle internal oracle;

    bytes32 internal pid;

    /// @notice Set up shared state for all tests
    function setUp() public {
        bolt = new Bolt(OWNER, SIGNER);
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
        stakingContract.createPool(GAME, CHALLENGE, USER_ID);

        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);

        // Assertions
        assertEq(pool.id, pid, "Pool ID mismatch");
        assertEq(pool.totalStaked, 0, "Initial totalStaked should be zero");
        assertEq(pool.totalShares, 0, "Initial totalShares should be zero");
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
        stakingContract.createPool(GAME, CHALLENGE, USER_ID);
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

    function testFuzz_balancesAfterDepositPositiveReward(
        int256 _rewardAmount,
        uint256 _amountStakedFirst,
        uint256 _amountStakedSecond
    ) public {
        // build
        vm.assume(
            _amountStakedFirst > 0 && _amountStakedFirst < 5_000_000_000_000_000
        );
        vm.assume(_rewardAmount > 0 && _rewardAmount < 2_200_000_000);
        vm.assume(
            _amountStakedSecond > 0 &&
                _amountStakedSecond < 5_000_000_000_000_000
        );

        vm.prank(OWNER);
        bolt.mint(STAKER1, _amountStakedFirst);
        vm.prank(OWNER);
        bolt.mint(STAKER2, _amountStakedSecond);

        // operate
        stakingContract.createPool(GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);

        uint256 balanceStaker1BeforeDeposit = bolt.balanceOf(STAKER1);
        uint256 balanceStaker2BeforeDeposit = bolt.balanceOf(STAKER2);

        stakeToken(STAKER1, _amountStakedFirst);
        oracle.updatePool(pid, _rewardAmount, true);
        stakeToken(STAKER2, _amountStakedSecond);

        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);

        // check
        assertEq(
            bolt.balanceOf(address(stakingContract)),
            pool.totalStaked,
            "Balance of staking contract wrong"
        );
        assertEq(
            bolt.balanceOf(STAKER1),
            balanceStaker1BeforeDeposit - _amountStakedFirst,
            "Balance STAKER1 wrong after deposit"
        );
        assertEq(
            bolt.balanceOf(STAKER2),
            balanceStaker2BeforeDeposit - _amountStakedSecond,
            "Balance STAKER2 wrong after deposit"
        );
        assertEq(
            bolt.balanceOf(DEVADDR),
            0,
            "DEVADDR balance wrong after deposit"
        );
    }

    function testFuzz_balancesAfterDepositNegReward(
        int256 _rewardAmount,
        uint256 _amountStakedFirst,
        uint256 _amountStakedSecond
    ) public {
        vm.assume(
            _amountStakedFirst > 0 && _amountStakedFirst < 5_000_000_000_000_000
        );
        vm.assume(
            _rewardAmount > -int256(_amountStakedFirst) && _rewardAmount < 0
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
        stakingContract.createPool(GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);

        uint256 balanceStaker1BeforeDeposit = bolt.balanceOf(STAKER1);
        uint256 balanceStaker2BeforeDeposit = bolt.balanceOf(STAKER2);
        uint256 balanceDevBeforeDeposits = bolt.balanceOf(DEVADDR);

        stakeToken(STAKER1, _amountStakedFirst);
        oracle.updatePool(pid, _rewardAmount, true);
        stakeToken(STAKER2, _amountStakedSecond);

        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);

        // check
        assertEq(
            bolt.balanceOf(address(stakingContract)) - uint256(-_rewardAmount),
            pool.totalStaked,
            "Balance of staking contract wrong"
        );
        assertEq(
            bolt.balanceOf(STAKER1),
            balanceStaker1BeforeDeposit - _amountStakedFirst,
            "Balance STAKER1 wrong after deposit"
        );
        assertEq(
            bolt.balanceOf(STAKER2),
            balanceStaker2BeforeDeposit - _amountStakedSecond,
            "Balance STAKER2 wrong after deposit"
        );

        assertEq(
            bolt.balanceOf(DEVADDR),
            uint256(-_rewardAmount),
            "DEVADDR balance wrong after deposit with neg reward"
        );
    }

    /// @notice Test that pool creation reverts if the game is invalid
    function testFail_InvalidGameRevertsOnPoolCreation() public {
        stakingContract.createPool("InvalidGame", CHALLENGE, USER_ID);
    }

    function testFail_CreateMoreTokensThanPossible() public {
        bolt = new Bolt(OWNER, SIGNER);
        bolt.mint(OWNER, 1e40);
    }
    /*//////////////////////////////////////////////////////////////
                      UTILITY FUNCTIONS FOR SUITE
    //////////////////////////////////////////////////////////////*/

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
}
