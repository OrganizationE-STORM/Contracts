// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {EBolt} from "../../src/EBolt.sol";
import {StakingContract} from "../../src/StakingContract.sol";
import {EStormOracle} from "../../src/EStormOracle.sol";
import {console} from "forge-std/console.sol";

contract DepositRevertsTest is Test {
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
    EBolt internal bolt;
    StakingContract internal stakingContract;
    EStormOracle internal oracle;

    bytes32 internal pid;

    /// @notice Set up shared state for all tests
    function setUp() public {
        bolt = new EBolt(OWNER, SIGNER, DEVADDR);
        oracle = new EStormOracle();
        pid = keccak256(abi.encode(GAME, CHALLENGE, USER_ID));
        stakingContract = new StakingContract(bolt, oracle, DEVADDR);
        stakingContract.addGame(GAME);
        vm.prank(OWNER);
        bolt.setStakingContract(address(stakingContract));
        oracle.setStakingContract(address(stakingContract));

        vm.prank(DEVADDR);
        bolt.approve(address(stakingContract), type(uint256).max);
    }

    function testFail_theStakerDoesNotHaveSpecifiedAmountInBalance() public {
        uint256 amountStaked = 100;
        stakingContract.createPool(GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);
        stakeToken(STAKER1, amountStaked);
    }

    /// @notice Test that deposits revert if the pool is not active
    function testFail_DepositRevertsIfPoolNotActive() public {
        stakingContract.createPool(GAME, CHALLENGE, USER_ID);

        vm.prank(STAKER1);
        stakingContract.deposit(500, pid);
    }

    function testFail_depositZeroTokens() public {
        stakingContract.createPool(GAME, CHALLENGE, USER_ID);
        oracle.updatePool(pid, 0, true);
        vm.prank(STAKER1);
        stakingContract.deposit(0, pid);
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
