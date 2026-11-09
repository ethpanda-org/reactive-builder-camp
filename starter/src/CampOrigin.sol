// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title CampOrigin — 源链上的「事件发射器」（部署在 Sepolia 等源链）
/// @notice 三步走的第 1 步：在源链发出一个事件。真实项目里这一步通常是别人的合约
///         （ERC-20 Transfer、Uniswap Sync…），这里用一个最小合约方便自己触发。
contract CampOrigin {
    /// @dev topic0 = keccak256("Ping(address,uint256)")；who 是 indexed → topic1；value 在 data 里
    event Ping(address indexed who, uint256 value);

    function ping(uint256 value) external {
        emit Ping(msg.sender, value);
    }
}
