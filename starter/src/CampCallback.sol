// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";

/// @title CampCallback — 共学模板的目标链回调合约（部署在 Sepolia / Base Sepolia / Unichain Sepolia）
/// @notice 只接受「本链 Callback Proxy」发来的、且 payload 里注入的 reactive 地址等于 _CALLBACK_SENDER 的调用。
///         这是三步走的第 3 步，也是黑客松评审的硬门槛：链上必须能看到这笔回调交易。
/// @dev    回调由接收方用目标链原生币付费（ETH），所以部署时要带 value；
///         _CALLBACK_SENDER 不可更改，填错只能重新部署。
contract CampCallback is AbstractCallback {
    /// @notice 回调到达时发出；拿这笔交易哈希去交黑客松
    event Handled(address indexed reactive, uint256 indexed originChainId, uint256 originTxHash, uint256 value, uint256 count);

    uint256 public count;
    uint256 public lastValue;
    uint256 public lastOriginTxHash;

    /// @param proxy_    本链的 Callback Proxy 地址（见 docs/cheatsheet.md）
    /// @param reactive_ 允许给本合约发回调的 Reactive 合约地址
    constructor(IPayable proxy_, address reactive_) payable AbstractCallback(proxy_, reactive_) {}

    /// @notice 被 Callback Proxy 调用的函数。第一个参数由网络注入，不是你在 payload 里填的 address(0)。
    function onEvent(address reactive_, uint256 originChainId_, uint256 originTxHash_, uint256 value_)
        external
        onlyServiceProvider
        onlyCallbackSender(reactive_)
    {
        count += 1;
        lastValue = value_;
        lastOriginTxHash = originTxHash_;
        emit Handled(reactive_, originChainId_, originTxHash_, value_, count);
    }
}
