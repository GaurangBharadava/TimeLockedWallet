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

    event timeLockUpdated(uint32 duration);
    event deposited(uint256 amount, uint256 timestamp);

    uint256 private timeLock;
    uint32 public immutable duration = 10 days;
    uint256 ethBalance;
    // uint256 tokenBalance;

    constructor(uint256 _lockTime) Ownable(msg.sender) {
        timeLock = _lockTime;
    }

    function getTimeLock() external view onlyOwner returns (uint256) {
        return timeLock;
    }

    function deposit() external payable {
        if (msg.value == 0) {
            revert Wallet__canNotDepositZeroValue();
        }
        emit deposited(msg.value, block.timestamp);
        ethBalance = ethBalance + msg.value;
        _setTimeLock();
    }

    function withdraw(uint256 _amount) external onlyOwner nonReentrant {
        if (block.timestamp < timeLock) {
            revert Wallet__fundsAreLocked();
        }
        if (ethBalance == 0) {
            revert Wallet_missingFunds();
        }
        if (_amount > ethBalance) {
            revert Wallet__insufficiantFundsInWallet();
        }
        (bool ok,) = payable(owner()).call{value: _amount}("");
        if (!ok) {
            revert Wallet__withdrawelFailed();
        }
    }

    function _setTimeLock() private {
        emit timeLockUpdated(duration);
        timeLock = block.timestamp + uint256(duration);
    }

    function getBalance() external view onlyOwner returns (uint256) {
        return ethBalance;
    }
}
