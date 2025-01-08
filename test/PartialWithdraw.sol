// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Bolt} from "../src/Bolt.sol";
import {StakingContract} from "../src/StakingContract.sol";
import {EStormOracle} from "../src/EStormOracle.sol";
import {console} from "forge-std/console.sol";
import {TestingLibrary} from "./TestingLibrary.sol";

contract WithdrawTest is Test {
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

    function testFuzz_partialWithdrawIsCorrect(
        int256 _rewardFromOracle,
        uint256 _amountStaker1,
        uint256 _amountStaker2,
        uint256 _amountStaker3
    ) public {
        vm.assume(_amountStaker1 > 0 && _amountStaker1 < 5_000_000_000_000_000);
        vm.assume(_rewardFromOracle > 0 && _rewardFromOracle < 2_200_000_000);
        vm.assume(_amountStaker2 > 0 && _amountStaker2 < 5_000_000_000_000_000);
        vm.assume(_amountStaker3 > 0 && _amountStaker3 < 5_000_000_000_000_000);

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
        (uint256 staker3Reward, uint256 fee) = stakingContract
            .previewUnstakeReward(pid);
        uint256 balanceStaker3BeforeWithdraw = bolt.balanceOf(STAKER3);

        vm.prank(STAKER3);
        stakingContract.withdraw(
            pid
        );
        uint256 balanceStaker3AfterWithdraw = bolt.balanceOf(STAKER3);

        assertEq(
            balanceStaker3AfterWithdraw,
            balanceStaker3BeforeWithdraw + staker3Reward,
            "STAKER3 balance is wrong"
        );
    }

    function testFail_WithdrawMoreTokensThanAllowed() public {
        uint256 amountStaker1 = 100_000_000;
        int256 rewardFromOracle = 100_000;
        mint(STAKER1, amountStaker1);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);
        stakeToken(STAKER1, amountStaker1);
        oracle.updatePool(pid, rewardFromOracle, true);
        vm.prank(STAKER1);
        stakingContract.withdrawPartial(pid, amountStaker1 + 900_000);
    }

    function test_stakerWithdrawsPartOfTokens() public {
        uint256 amountStaker1 = 100_000_000;
        int256 rewardFromOracle = 100_000;
        mint(STAKER1, amountStaker1);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);
        stakeToken(STAKER1, amountStaker1);
        oracle.updatePool(pid, rewardFromOracle, true);
        uint256 balanceBeforeWithdraw = bolt.balanceOf(STAKER1);
        uint256 sharesBefore = stakingContract.getPool(pid).totalShares;
        vm.prank(STAKER1);
        stakingContract.withdrawPartial(pid, amountStaker1 / 2);
        uint256 balanceAfterWithdraw = bolt.balanceOf(STAKER1);
        uint256 sharesAfter = stakingContract.getPool(pid).totalShares;
        assertEq(balanceAfterWithdraw > balanceBeforeWithdraw, true, "Withdraw amount not right");
        assertEq(
            stakingContract.getPool(pid).totalStaked,
            amountStaker1 / 2 + uint256(rewardFromOracle),
            "Total staked wrong"
        );
        assertEq(
            sharesBefore > sharesAfter,
            true,
            "Total shares wrong"
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
}
