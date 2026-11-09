// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test, Vm } from "forge-std/Test.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { CampOrigin } from "../src/CampOrigin.sol";
import { CampReactive } from "../src/CampReactive.sol";
import { CampCallback } from "../src/CampCallback.sol";

/// @dev 本地模拟 Reactive 系统合约（0x8888…）：记录订阅/退订，把回调请求存起来，供测试「投递」到目标链。
contract MockSystem {
    struct Sub { uint256 chainId; address contract_; uint256 topic0; }
    Sub[] public subs;
    uint256 public unsubscribeCount;
    ISystemContract.CallbackConfiguration_V_1_0[] public requests;

    function subscribe(uint256 c, address a, uint256 t0, uint256, uint256, uint256) external { subs.push(Sub(c, a, t0)); }
    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external { unsubscribeCount++; }
    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory cfg) external { requests.push(cfg); }
    function debt(address) external pure returns (uint256) { return 0; }
    function requestCount() external view returns (uint256) { return requests.length; }
    function lastRequest() external view returns (ISystemContract.CallbackConfiguration_V_1_0 memory) { return requests[requests.length - 1]; }
    receive() external payable {}
}

/// @dev 本地模拟目标链 Callback Proxy：把 payload 第一个 address 参数替换成 reactive 地址再调用，和真实网络行为一致。
contract MockProxy {
    function debt(address) external pure returns (uint256) { return 0; }
    receive() external payable {}
    function deliver(address recipient, address reactive, bytes memory payload) external returns (bool ok, bytes memory ret) {
        // payload = selector(4) ++ abi.encode(address(0), ...) → 覆盖第 4..36 字节
        assembly {
            mstore(add(payload, 36), reactive)
        }
        (ok, ret) = recipient.call(payload);
    }
}

contract CampTest is Test {
    uint256 constant ORIGIN_CHAIN = 11155111;
    uint256 constant DEST_CHAIN = 11155111;
    uint256 constant THRESHOLD = 100;
    uint256 constant LIMIT = 2;

    MockSystem system;
    MockProxy proxy;
    CampOrigin origin;
    CampReactive reactive;
    CampCallback callback;
    uint256 topic0;

    function setUp() public {
        // 把 MockSystem 的代码放到 0x8888… 上，让 AbstractReactive 里的常量 SYSTEM 指向它
        MockSystem impl = new MockSystem();
        vm.etch(0x8888888888888888888888888888888888888888, address(impl).code);
        system = MockSystem(payable(0x8888888888888888888888888888888888888888));
        proxy = new MockProxy();
        origin = new CampOrigin();
        topic0 = uint256(keccak256("Ping(address,uint256)"));

        reactive = new CampReactive{ value: 1 ether }(ORIGIN_CHAIN, address(origin), topic0, DEST_CHAIN, THRESHOLD, LIMIT);
        callback = new CampCallback{ value: 0.1 ether }(IPayable(payable(address(proxy))), address(reactive));
        reactive.setRecipient(address(callback));
    }

    function _log(uint256 value, uint256 txHash) internal view returns (IReactive.LogRecord memory l) {
        l.chainId = ORIGIN_CHAIN;
        l.contractAddress = address(origin);
        l.topic0 = topic0;
        l.topic1 = uint256(uint160(address(this)));
        l.data = abi.encode(value);
        l.opCode = 2;
        l.txHash = txHash;
        l.blockNumber = 1;
    }

    function test_subscribedInConstructor() public view {
        (uint256 c, address a, uint256 t0) = system.subs(0);
        assertEq(c, ORIGIN_CHAIN); assertEq(a, address(origin)); assertEq(t0, topic0);
    }

    function test_reactOnlySystem() public {
        vm.expectRevert();
        reactive.react(_log(500, 1));
    }

    function test_belowThresholdNoCallback() public {
        vm.prank(address(system));
        reactive.react(_log(THRESHOLD - 1, 1));
        assertEq(system.requestCount(), 0);
        assertEq(reactive.remaining(), LIMIT);
        assertEq(reactive.lastTxHash(), 1);
    }

    function test_fullLoop_eventToCallback() public {
        vm.prank(address(system));
        reactive.react(_log(500, 0xabc));
        assertEq(system.requestCount(), 1);
        ISystemContract.CallbackConfiguration_V_1_0 memory r = system.lastRequest();
        assertEq(r.chainId, DEST_CHAIN);
        assertEq(r.recipient, address(callback));

        // 模拟目标链 proxy 投递
        (bool ok,) = proxy.deliver(address(callback), address(reactive), r.payload);
        assertTrue(ok);
        assertEq(callback.count(), 1);
        assertEq(callback.lastValue(), 500);
        assertEq(callback.lastOriginTxHash(), 0xabc);
    }

    function test_callbackRejectsWrongProxy() public {
        bytes memory payload = abi.encodeWithSignature("onEvent(address,uint256,uint256,uint256)", address(reactive), 1, 2, 3);
        (bool ok,) = address(callback).call(payload); // 直接调用，msg.sender 不是 proxy
        assertFalse(ok);
        assertEq(callback.count(), 0);
    }

    function test_callbackRejectsWrongSender() public {
        bytes memory payload = abi.encodeWithSignature("onEvent(address,uint256,uint256,uint256)", address(0), 1, 2, 3);
        (bool ok,) = proxy.deliver(address(callback), address(0xBEEF), payload); // 注入的 reactive 地址不对
        assertFalse(ok);
        assertEq(callback.count(), 0);
    }

    function test_limitReachedUnsubscribes() public {
        vm.startPrank(address(system));
        reactive.react(_log(500, 1));
        reactive.react(_log(500, 2));
        reactive.react(_log(500, 3)); // 第三次：remaining 已为 0，直接 return
        vm.stopPrank();
        assertEq(system.requestCount(), 2);
        assertEq(system.unsubscribeCount(), 1);
        assertEq(reactive.remaining(), 0);
    }

    function test_originEmitsPing() public {
        vm.recordLogs();
        origin.ping(42);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(uint256(logs[0].topics[0]), topic0);
        assertEq(abi.decode(logs[0].data, (uint256)), 42);
    }
}
