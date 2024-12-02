// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bolt} from "../src/Bolt.sol";

contract BoltTest is Test {
    Bolt public bolt;

    function setUp() public {
        bolt = new Bolt(address(0));
    }

    function test_OwnerChangesNotaryAddress() public {
        address notaryBefore = bolt.notary();
        bolt.setNotary(address(1));
        assertEq(notaryBefore, address(0));
        assertEq(bolt.notary(), address(1));
    }

    /*//////////////////////////////////////////////////////////////
                       TESTS THAT SHOULD REVERTS
    //////////////////////////////////////////////////////////////*/
    function test_RevertIfNonOwnerChangesNotaryAddress() public {
        vm.expectRevert();
        vm.startPrank(address(1));
        bolt.setNotary(address(1));
    }
}
