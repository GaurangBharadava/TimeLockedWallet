// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Wallet} from "../src/TimelockedWallet.sol";

contract DeployWallet is Script {
    Wallet public wallet;

    function run() external returns (Wallet) {
        vm.startBroadcast();
        wallet = new Wallet();
        vm.stopBroadcast();
        return wallet;
    }
}
