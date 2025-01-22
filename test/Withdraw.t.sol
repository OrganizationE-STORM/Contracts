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

    function testFuzz_withdrawIsCorrect(
        int256 _rewardFromOracle,
        uint256 _amountStaker1,
        uint256 _amountStaker2,
        uint256 _amountStaker3
    ) public {
        vm.assume(
            _amountStaker1 > 10 && _amountStaker1 < 5_000_000_000_000_000
        );
        vm.assume(_amountStaker2 > 0 && _amountStaker2 < 5_000_000_000_000_000);
        vm.assume(_amountStaker3 > 0 && _amountStaker3 < 5_000_000_000_000_000);
        vm.assume(
            _rewardFromOracle >
                -int256(_amountStaker1 + _amountStaker2 + _amountStaker3) &&
                _rewardFromOracle < 2_200_000_000
        );

        mint(STAKER1, _amountStaker1);
        mint(STAKER2, _amountStaker2);
        mint(STAKER3, _amountStaker3);

        vm.assume(_rewardFromOracle > 0);
        stakingContract.createPool(50, 50, GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);

        stakeToken(STAKER1, _amountStaker1);
        console.log(stakingContract.getPool(pid).totalStaked);
        stakeToken(STAKER2, _amountStaker2);
        console.log(stakingContract.getPool(pid).totalStaked);
        stakeToken(STAKER3, _amountStaker3);
        console.log(stakingContract.getPool(pid).totalStaked);

        assertEq(
            stakingContract.getPool(pid).totalStaked,
            _amountStaker2 + _amountStaker1 + _amountStaker3,
            "Total staked is not updated correctly"
        );

        oracle.updatePool(pid, _rewardFromOracle, true);

        uint256 totalStakedByStaker1 = stakingContract.convertToAssets(
            stakingContract.sharesByAddress(pid, STAKER1),
            pid
        );

        console.log("totalStakedByStaker1", totalStakedByStaker1);

        vm.prank(STAKER1);
        stakingContract.withdraw(pid, totalStakedByStaker1);
        console.log(stakingContract.getPool(pid).totalStaked);
        
        uint256 totalStakedByStaker2 = stakingContract.convertToAssets(
            stakingContract.sharesByAddress(pid, STAKER2),
            pid
        );
        
        
        vm.prank(STAKER2);
        stakingContract.withdraw(pid, totalStakedByStaker2);

        StakingContract.PoolInfo memory poolInfo = stakingContract.getPool(pid);
        console.log("totalStakedByStaker2", totalStakedByStaker2, stakingContract.sharesByAddress(pid, STAKER2), poolInfo.totalShares);
        
        uint256 totalStakedByStaker3 = stakingContract.convertToAssets(
            stakingContract.sharesByAddress(pid, STAKER3),
            pid
        );
        console.log("totalStakedByStaker3", totalStakedByStaker3, stakingContract.sharesByAddress(pid, STAKER3), poolInfo.totalShares);

        vm.prank(STAKER3);
        stakingContract.withdraw(pid, totalStakedByStaker3);
        console.log(stakingContract.getPool(pid).totalStaked);
        
        assertEq(
            stakingContract.sharesByAddress(pid, STAKER1),
            0,
            "STAKER1 shares should be 0 after withdraw"
        );
        assertEq(
            stakingContract.sharesByAddress(pid, STAKER2),
            0,
            "STAKER2 shares should be 0 after withdraw"
        );
        assertEq(
            stakingContract.sharesByAddress(pid, STAKER3),
            0,
            "STAKER3 shares should be 0 after withdraw"
        );
        
        assertEq(stakingContract.getPool(pid).totalShares, 0);
        assertEq(stakingContract.getPool(pid).totalStaked, 0);
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
