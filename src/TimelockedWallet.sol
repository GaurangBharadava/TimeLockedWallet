// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Wallet is Ownable, ReentrancyGuard {
    error Wallet__canNotDepositZeroValue();
    error Wallet__insufficiantFundsInWallet();
    error Wallet__withdrawelFailed();
    error Wallet__fundsAreLocked();
    error Wallet_missingFunds();
    // error Wallet__walletIsLocked();

    event TimeLockUpdated(uint32 duration);
    event Deposited(uint256 amount, uint256 timestamp);
    event Withdrawed(uint256 amount);
    event LockExtended(uint256 time);

    uint256 private timeLock;
    uint32 public immutable duration = 2 days;
    uint8 public immutable penaltyPercent = 10;
    uint256 ethBalance;
    uint256 penalty;
    bool lock;
    // uint256 tokenBalance;

    constructor() Ownable(msg.sender) {
        timeLock = block.timestamp + duration;
    }

    function getTimeLock() external view onlyOwner returns (uint256) {
        return timeLock;
    }

    function deposit() external payable onlyOwner {
        if (msg.value == 0) {
            revert Wallet__canNotDepositZeroValue();
        }
        emit Deposited(msg.value, block.timestamp);
        ethBalance = ethBalance + msg.value;
        _setTimeLock();
    }

    function partialWithdraw(uint256 _amount) external onlyOwner nonReentrant {
        if (block.timestamp < timeLock) {
            revert Wallet__fundsAreLocked();
        }
        if (ethBalance == 0) {
            revert Wallet_missingFunds();
        }
        if (_amount > ethBalance) {
            revert Wallet__insufficiantFundsInWallet();
        }
        ethBalance = ethBalance - _amount;
        (bool ok,) = payable(owner()).call{value: _amount}("");
        emit Withdrawed(_amount);
        if (!ok) {
            revert Wallet__withdrawelFailed();
        }
    }

    function withdraw() external onlyOwner nonReentrant {
        if (block.timestamp < timeLock) {
            revert Wallet__fundsAreLocked();
        }

        if (ethBalance == 0) {
            revert Wallet_missingFunds();
        }
        uint256 amount = ethBalance;
        ethBalance = 0;
        (bool ok,) = payable(owner()).call{value: amount}("");
        emit Withdrawed(amount);
        if (!ok) {
            revert Wallet__withdrawelFailed();
        }
    }

    // function emergencyUnlock() external onlyOwner nonReentrant {
    //     uint256 balance = ethBalance;
    //     uint256 fees = (balance * penaltyPercent) / 100;
    //     penalty += fees;
    //     ethBalance -= fees;

    // }

    function extendLock(uint256 _time) external onlyOwner nonReentrant {
        require(_time > 0, "Time for lock extend has to be more then zero");
        timeLock += _time;
        emit LockExtended(_time);
    }

    function _setTimeLock() private {
        // lock = true;
        timeLock = block.timestamp + uint256(duration);
        emit TimeLockUpdated(duration);
    }

    function getBalance() external view onlyOwner returns (uint256) {
        return ethBalance;
    }

    receive() external payable {
        ethBalance += msg.value;
        emit Deposited(msg.value, block.timestamp);
    }

    fallback() external payable {
        ethBalance += msg.value;
        emit Deposited(msg.value, block.timestamp);
    }
}
