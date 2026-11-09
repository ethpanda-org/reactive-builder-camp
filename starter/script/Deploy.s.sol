// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { CampOrigin } from "../src/CampOrigin.sol";
import { CampReactive } from "../src/CampReactive.sol";
import { CampCallback } from "../src/CampCallback.sol";

/// 第 1 步：源链部署事件发射器
///   forge script script/Deploy.s.sol:DeployOrigin --rpc-url $SEPOLIA_RPC_URL --broadcast
contract DeployOrigin is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        CampOrigin o = new CampOrigin();
        vm.stopBroadcast();
        console.log("ORIGIN_ADDR=", address(o));
    }
}

/// 第 2 步：Lasna 部署 Reactive 合约（带 lREACT 预付款）
///   forge script script/Deploy.s.sol:DeployReactive --rpc-url $LASNA_RPC_URL --broadcast
contract DeployReactive is Script {
    function run() external {
        uint256 originChain = vm.envUint("ORIGIN_CHAIN_ID");
        address originAddr = vm.envAddress("ORIGIN_ADDR");
        uint256 destChain = vm.envUint("DEST_CHAIN_ID");
        uint256 threshold = vm.envOr("THRESHOLD", uint256(100));
        uint256 limit = vm.envOr("LIMIT", uint256(5));
        uint256 fund = vm.envOr("REACTIVE_FUND", uint256(0.5 ether)); // lREACT
        uint256 topic0 = uint256(keccak256("Ping(address,uint256)"));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        CampReactive r = new CampReactive{ value: fund }(originChain, originAddr, topic0, destChain, threshold, limit);
        vm.stopBroadcast();
        console.log("REACTIVE_ADDR=", address(r));
    }
}

/// 第 3 步：目标链部署回调合约（带 ETH，用来付回调 gas），然后回 Lasna setRecipient
///   forge script script/Deploy.s.sol:DeployCallback --rpc-url $SEPOLIA_RPC_URL --broadcast
contract DeployCallback is Script {
    function run() external {
        address proxy = vm.envAddress("CALLBACK_PROXY");
        address reactive = vm.envAddress("REACTIVE_ADDR");
        uint256 fund = vm.envOr("CALLBACK_FUND", uint256(0.02 ether));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        CampCallback c = new CampCallback{ value: fund }(IPayable(payable(proxy)), reactive);
        vm.stopBroadcast();
        console.log("CALLBACK_ADDR=", address(c));
    }
}

/// 第 4 步：Lasna 上把回调合约地址告诉 Reactive 合约
///   forge script script/Deploy.s.sol:SetRecipient --rpc-url $LASNA_RPC_URL --broadcast
contract SetRecipient is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        CampReactive(payable(vm.envAddress("REACTIVE_ADDR"))).setRecipient(vm.envAddress("CALLBACK_ADDR"));
        vm.stopBroadcast();
        console.log("recipient set");
    }
}

/// 第 5 步：源链触发事件（value 要 >= threshold 才会回调）
///   forge script script/Deploy.s.sol:Ping --rpc-url $SEPOLIA_RPC_URL --broadcast
contract Ping is Script {
    function run() external {
        uint256 value = vm.envOr("PING_VALUE", uint256(500));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        CampOrigin(vm.envAddress("ORIGIN_ADDR")).ping(value);
        vm.stopBroadcast();
        console.log("pinged with value", value);
    }
}
