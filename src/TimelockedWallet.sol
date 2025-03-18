// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Wallet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error Wallet__canNotDepositZeroValue();
    error Wallet__insufficiantFundsInWallet();
    error Wallet__withdrawelFailed();
    error Wallet__fundsAreLocked();
    error Wallet__missingFunds();
    error Wallet__zeroAddress();
    error Wallet__canNotSendZeroAmount();
    error Wallet__transactionFailed();
    error Wallet__canNotSendMoreThenBalance();
    error Wallet__wrongToken();
    // error Wallet__walletIsLocked();

    event TimeLockUpdated(uint32 duration);
    event Deposited(uint256 amount, uint256 timestamp);
    event Withdrawed(uint256 amount);
    event LockExtended(uint256 time);

    uint256 private timeLock;
    uint32 public immutable duration = 2 days;
    uint8 public immutable penaltyPercent = 10;
    mapping(address token => uint256 balance) public tokenToBalance;
    uint256 ethBalance;
    uint256 penalty;
    // bool lock;
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

    function depositeFTokens(address _token, uint256 _amount) external onlyOwner {
        if (_amount == 0) {
            revert Wallet__canNotDepositZeroValue();
        }
        if (_token == address(0)) {
            revert Wallet__wrongToken();
        }
        tokenToBalance[_token] += _amount;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(_amount, block.timestamp);
        _setTimeLock();
    }

    function partialwithdrawFToken(address _token, uint256 _amount) external onlyOwner nonReentrant {
        if (block.timestamp < timeLock) {
            revert Wallet__fundsAreLocked();
        }
        if (_token == address(0)) {
            revert Wallet__wrongToken();
        }
        if (_amount == 0) {
            revert Wallet__missingFunds();
        }
        if (_amount > tokenToBalance[_token]) {
            revert Wallet__insufficiantFundsInWallet();
        }
        tokenToBalance[_token] -= _amount;
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Withdrawed(_amount);
    }

    function withdrawFtoken(address _token) external onlyOwner nonReentrant {
        if (block.timestamp < timeLock) {
            revert Wallet__fundsAreLocked();
        }
        if (_token == address(0)) {
            revert Wallet__wrongToken();
        }
        uint256 amount = tokenToBalance[_token];
        tokenToBalance[_token] = 0;
        IERC20(_token).safeTransfer(msg.sender, amount);
        emit Withdrawed(amount);
    }

    function partialWithdraw(uint256 _amount) external onlyOwner nonReentrant {
        if (block.timestamp < timeLock) {
            revert Wallet__fundsAreLocked();
        }
        if (ethBalance == 0) {
            revert Wallet__missingFunds();
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
            revert Wallet__missingFunds();
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

    function sendEth(address _to, uint256 _amount) external onlyOwner nonReentrant {
        if (block.timestamp < timeLock) {
            revert Wallet__fundsAreLocked();
        }
        if (payable(address(_to)) == address(0)) {
            revert Wallet__zeroAddress();
        }
        if (_amount == 0) {
            revert Wallet__canNotSendZeroAmount();
        }

        if (ethBalance < _amount) {
            revert Wallet__canNotSendMoreThenBalance();
        }

        ethBalance -= _amount;
        (bool ok,) = payable(_to).call{value: _amount}("");
        if (!ok) {
            revert Wallet__transactionFailed();
        }
        _setTimeLock();
    }

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
