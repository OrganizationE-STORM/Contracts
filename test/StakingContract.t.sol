pragma solidity ^0.8.22;
import {Test} from "forge-std/Test.sol";
import {Bolt} from "../src/Bolt.sol";
import {StakingContract} from "../src/StakingContract.sol";

contract StakingContractPoolCreationTest is Test {
    string game = "LOL";
    string challenge = "WOG";
    string userID = "Alessio";
    address owner = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    Bolt bolt;

    function setUp() public {
        bolt = new Bolt(owner);
    }
    function test_aPoolIsSuccesfullyCreated() public {
        bytes32 pid = keccak256(abi.encode(game, challenge, userID));
        StakingContract stakingContract = new StakingContract(address(bolt));
        stakingContract.addGame(game);
        stakingContract.createPool(50, 50, game, challenge, userID);
        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);
        assertEq(pool.id, pid);
    }
    function testFail_RevertIfGameIsInvalid() public {
        StakingContract stakingContract = new StakingContract(address(bolt));
        stakingContract.createPool(50, 50, game, challenge, userID);
    }
}
