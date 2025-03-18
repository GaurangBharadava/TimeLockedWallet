// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Wallet} from "../src/TimelockedWallet.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TestTimelockedWallet is Test {
    event TimeLockUpdated(uint32 duration);
    event Deposited(uint256 amount, uint256 timestamp);
    event Withdrawed(uint256 amount);
    event LockExtended(uint256 time);

    Wallet public wallet;
    address public usdc;
    address public btc;
    address owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);
        wallet = new Wallet();
        usdc = address(new ERC20Mock());
        btc = address(new ERC20Mock());
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
        vm.expectRevert(Wallet.Wallet__missingFunds.selector);
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

    function testZeroAmountCanNotFullWithdraw() public {
        vm.startPrank(owner);
        vm.warp(wallet.getTimeLock() + 3 days);
        vm.expectRevert(Wallet.Wallet__missingFunds.selector);
        wallet.withdraw();
        vm.stopPrank();
    }

    function testZeroAmountCanNotPartialWithdraw() public {
        vm.startPrank(owner);
        vm.warp(wallet.getTimeLock() + 3 days);
        vm.expectRevert(Wallet.Wallet__missingFunds.selector);
        wallet.partialWithdraw(1 ether);
        vm.stopPrank();
    }

    function testAllEvent() public {
        vm.startPrank(owner);
        vm.expectEmit();
        emit Wallet.LockExtended(2 days);
        wallet.extendLock(2 days);

        vm.expectEmit();
        emit Wallet.Deposited(10 ether, block.timestamp);
        vm.expectEmit();
        emit Wallet.TimeLockUpdated(2 days);
        wallet.deposit{value: 10 ether}();

        vm.warp(wallet.getTimeLock() + 3 days);
        vm.expectEmit();
        emit Wallet.Withdrawed(10 ether);
        wallet.withdraw();

        wallet.deposit{value: 10 ether}();
        vm.warp(wallet.getTimeLock() + 3 days);
        vm.expectEmit();
        emit Wallet.Withdrawed(5 ether);
        wallet.partialWithdraw(5 ether);

        vm.stopPrank();
    }

    function testDepositeFtoken() public {
        vm.startPrank(owner);
        ERC20Mock(usdc).mint(owner, 10e18);
        ERC20Mock(btc).mint(owner, 10e18);
        ERC20Mock(usdc).approve(address(wallet), 10e18);
        ERC20Mock(btc).approve(address(wallet), 10e18);
        wallet.depositeFTokens(usdc, 10);
        wallet.depositeFTokens(btc, 1e18);
        vm.stopPrank();
        assertEq(wallet.tokenToBalance(usdc), 10);
        assertEq(wallet.tokenToBalance(btc), 1e18);
        assertEq(IERC20(usdc).balanceOf(owner), 9999999999999999990);
        assertEq(IERC20(btc).balanceOf(owner), 9e18);
    }

    function testNonOwnerCannotDepositeFtoken() public {
        address user = makeAddr("user");
        vm.startPrank(user);
        ERC20Mock(usdc).mint(user, 10e18);
        ERC20Mock(btc).mint(user, 10e18);
        ERC20Mock(usdc).approve(address(wallet), 10e18);
        ERC20Mock(btc).approve(address(wallet), 10e18);
        vm.expectRevert();
        wallet.depositeFTokens(usdc, 10);
        vm.expectRevert();
        wallet.depositeFTokens(btc, 1e18);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(owner);
        ERC20Mock(usdc).mint(owner, 10e18);
        ERC20Mock(btc).mint(owner, 10e18);
        ERC20Mock(usdc).approve(address(wallet), 10e18);
        ERC20Mock(btc).approve(address(wallet), 10e18);
        wallet.depositeFTokens(usdc, 1e18);
        wallet.depositeFTokens(btc, 1e18);
        vm.stopPrank();
        assertEq(wallet.tokenToBalance(usdc), 1e18);
        assertEq(wallet.tokenToBalance(btc), 1e18);
        assertEq(IERC20(usdc).balanceOf(owner), 9e18);
        assertEq(IERC20(btc).balanceOf(owner), 9e18);

        vm.startPrank(owner);
        vm.warp(wallet.getTimeLock() + 3 days);
        wallet.withdrawFtoken(usdc);
        vm.stopPrank();
        assertEq(IERC20(usdc).balanceOf(owner), 10e18);
        assertEq(wallet.tokenToBalance(usdc), 0);
    }

    function testPartialFWithdraw() public {
        vm.startPrank(owner);
        ERC20Mock(usdc).mint(owner, 10e18);
        ERC20Mock(btc).mint(owner, 10e18);
        ERC20Mock(usdc).approve(address(wallet), 10e18);
        ERC20Mock(btc).approve(address(wallet), 10e18);
        wallet.depositeFTokens(usdc, 1e18);
        wallet.depositeFTokens(btc, 1e18);
        vm.stopPrank();
        assertEq(wallet.tokenToBalance(usdc), 1e18);
        assertEq(wallet.tokenToBalance(btc), 1e18);
        assertEq(IERC20(usdc).balanceOf(owner), 9e18);
        assertEq(IERC20(btc).balanceOf(owner), 9e18);

        vm.startPrank(owner);
        vm.warp(wallet.getTimeLock() + 3 days);
        wallet.partialwithdrawFToken(usdc, 1e16);
        vm.stopPrank();
        console2.log("Wallet balance: ", wallet.tokenToBalance(usdc));
    }
}
