pragma solidity ^0.8.22;
import {Test} from "forge-std/Test.sol";
import {Bolt} from "../src/Bolt.sol";
import {StakingContract} from "../src/StakingContract.sol";

contract StakingContractPoolCreationTest is Test {
    address owner = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    Bolt bolt;

    function setUp() public {
        bolt = new Bolt(owner);
    }
    function test_aPoolIsSuccesfullyCreated() public {
        string memory game = "LOL";
        string memory challenge = "WOG";
        string memory userID = "Alessio";
        bytes32 pid = keccak256(abi.encode(game, challenge, userID));
        StakingContract stakingContract = new StakingContract(address(bolt));
        stakingContract.addGame(game);
        stakingContract.createPool(50, 50, game, challenge, userID);
        StakingContract.PoolInfo memory pool = stakingContract.getPool(pid);
        assertEq(pool.id, pid);
    }
}
