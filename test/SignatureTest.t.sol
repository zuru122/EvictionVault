// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EvictionVault.sol";

contract EvictionVaultTest is Test {
    EvictionVault vault;
    address owner1;
    address owner2;
    address user;

    receive() external payable {}  // ✅ allows test contract to receive ETH

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

}