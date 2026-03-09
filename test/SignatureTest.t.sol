// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EvictionVault.sol";

contract EvictionVaultTest is Test {
    EvictionVault vault;
    address owner1;
    address owner2;
    address user;

    receive() external payable {}

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        user = makeAddr("user");

        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vault = new EvictionVault{value: 10 ether}(owners, 2);
    }

    function test_Deposit() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vault.deposit{value: 1 ether}();
        assertEq(vault.balances(user), 1 ether);
    }
    
    function test_Withdraw() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vault.deposit{value: 1 ether}();
        vm.prank(user);
        vault.withdraw(1 ether);
        assertEq(vault.balances(user), 0);
    }

    function test_MultisigExecute() public {
        vm.prank(owner1);
        vault.submitTransaction(user, 1 ether, "");
        vm.prank(owner2);
        vault.confirmTransaction(0);
        skip(1 hours);
        vault.executeTransaction(0);

        (,,, bool executed,,,) = vault.transactions(0);
        assertTrue(executed);
    }
}