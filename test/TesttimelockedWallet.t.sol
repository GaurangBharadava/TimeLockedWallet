// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Wallet} from "../src/TimelockedWallet.sol";

contract TestTimelockedWallet is Test {
    Wallet public wallet;
    address owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);
        wallet = new Wallet();
        vm.stopPrank();
        vm.deal(owner, 100 ether);
    }

    function testOwnerHasEther() public view {
        assertEq(owner.balance, 100 ether);
    }

    function testOwnerCanDeposite() public {
        vm.prank(owner);
        wallet.deposit{value: 10 ether}();
        vm.prank(owner);
        assertEq(wallet.getBalance(), 10 ether);
        assertEq(address(wallet).balance, 10 ether);
    }

    function testNonOwnerCanNotDeposit() public {
        hoax(address(1), 10 ether);
        vm.expectRevert();
        wallet.deposit{value: 1 ether}();
    }

    function testGetTimeLick() public {
        vm.prank(owner);
        uint256 timeLock = wallet.getTimeLock();
        console2.log("the time lock is: ", timeLock);
    }

    function testExtendTimeLock() public {
        vm.prank(owner);
        uint256 time = wallet.getTimeLock();
        vm.prank(owner);
        wallet.extendLock(3 days);
        vm.prank(owner);
        uint256 timeAfter = wallet.getTimeLock();
        assertEq(3 days, timeAfter - time);
    }

    function testSendEtherFromReceiveOrFallback() public {
        address user1 = makeAddr("user1");
        vm.deal(user1, 10 ether);
        vm.startPrank(owner);
        wallet.deposit{value: 10 ether}();
        assertEq(wallet.getBalance(), 10 ether);
        assertEq(address(wallet).balance, 10 ether);
        vm.stopPrank();
        vm.startPrank(user1);
        (bool ok,) = payable(address(wallet)).call{value: 10 ether}("");
        require(ok, "Transfer failed");
        vm.stopPrank();
        vm.prank(owner);
        assertEq(wallet.getBalance(), 20 ether);
        assertEq(address(wallet).balance, 20 ether);
    }

    function testPartialWithdraw() public {
        vm.startPrank(owner);
        wallet.deposit{value: 100 ether}();
        assertEq(wallet.getBalance(), 100 ether);
        assertEq(address(wallet).balance, 100 ether);
        vm.warp(wallet.getTimeLock() + 3 days);
        wallet.partialWithdraw(10 ether);
        assertEq(wallet.getBalance(), 90e18);
        assertEq(address(wallet).balance, 90e18);
        assertEq(owner.balance, 10e18);
    }

    function testNonOwnerCanNotWithdraw() public {
        address hacker = makeAddr("hacker");
        vm.startPrank(owner);
        wallet.deposit{value: 100 ether}();
        assertEq(wallet.getBalance(), 100 ether);
        assertEq(address(wallet).balance, 100 ether);
        vm.stopPrank();
        vm.startPrank(hacker);
        vm.expectRevert();
        wallet.partialWithdraw(1e18);
        vm.stopPrank();
    }

    function testFullWithdraw() public {
        vm.startPrank(owner);
        wallet.deposit{value: 100 ether}();
        assertEq(wallet.getBalance(), 100 ether);
        assertEq(address(wallet).balance, 100 ether);
        vm.warp(wallet.getTimeLock() + 3 days);
        wallet.withdraw();
        assertEq(wallet.getBalance(), 0);
        assertEq(address(wallet).balance, 0);
        assertEq(owner.balance, 100e18);
        vm.stopPrank();
    }

    function testCannotWithdrawBeforeTimeLock() public {
        vm.startPrank(owner);
        wallet.deposit{value: 100 ether}();
        assertEq(wallet.getBalance(), 100 ether);
        assertEq(address(wallet).balance, 100 ether);
        vm.expectRevert();
        wallet.withdraw();
        vm.stopPrank();
    }

    function testCanNotDepositeZeroAmount() public {
        vm.startPrank(owner);

        vm.expectRevert(Wallet.Wallet__canNotDepositZeroValue.selector);
        wallet.deposit{value: 0}();
    }

    function testZeroAmountCanNotWithdrawAndMoreThenBalance() public {
        vm.startPrank(owner);
        vm.warp(wallet.getTimeLock() + 3 days);
        vm.expectRevert(Wallet.Wallet_missingFunds.selector);
        wallet.partialWithdraw(1 ether);
        wallet.deposit{value: 10 ether}();
        vm.warp(wallet.getTimeLock() + 3 days);
        vm.expectRevert(Wallet.Wallet__insufficiantFundsInWallet.selector);
        wallet.partialWithdraw(11 ether);
        vm.stopPrank();
    }

    function testZeroTimecanNotbeExtended() public {
        vm.startPrank(owner);
        wallet.deposit{value: 1 ether}();
        vm.expectRevert();
        wallet.extendLock(0);
        vm.stopPrank();
    }

    function testZeroAmountCanNotFullWithdrawAndMoreThenBalance() public {
        vm.startPrank(owner);
        vm.warp(wallet.getTimeLock() + 3 days);
        vm.expectRevert(Wallet.Wallet_missingFunds.selector);
        wallet.withdraw();
        vm.stopPrank();
    }
}
