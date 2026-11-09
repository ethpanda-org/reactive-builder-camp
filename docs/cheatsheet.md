# Reactive Omni 速查表（2026-11-08 核对）

> 来源：dev.reactive.network 文档表、reactive-lib-omni v0.1.0 源码、本仓库 `starter/` 的实测。所有地址都用 `cast code` 在链上确认过有代码。
> 官方文档有几处前后矛盾，见文末「官方资料里的矛盾」；**本表以 Omni 源码和文档表为准**。

## 1. 网络

| 网络 | chainId | RPC | 浏览器 | 币 | 用途 |
|---|---|---|---|---|---|
| Reactive 主网 | 1597 | https://mainnet-rpc.rnk.dev/ | https://reactscan.net | REACT | 正式项目 |
| **Lasna 测试网** | **5318007** | **https://lasna-rpc.rnk.dev/** | **https://lasna.reactscan.net** | **lREACT** | **本营统一用这个** |
| Ethereum Sepolia | 11155111 | https://ethereum-sepolia-rpc.publicnode.com | https://sepolia.etherscan.io | ETH | 源链 / 目标链，最省事 |
| Base Sepolia | 84532 | https://sepolia.base.org | https://sepolia.basescan.org | ETH | 赛道 1 可选，200ms 出块 |
| Unichain Sepolia | 1301 | https://sepolia.unichain.org | https://sepolia.uniscan.xyz | ETH | 赛道 1 可选，1s 出块 |

- **主网和测试网不能混用**：源链是测试网，Reactive 侧和目标链也必须是测试网。
- 只能作源链（不能收回调）的测试网：Avalanche Fuji、BSC Testnet、Polygon Amoy。
- 主网可用 12 条链：Abstract、Arbitrum、Avalanche、Base、BSC、Ethereum、HyperEVM、Linea、Plasma、Reactive、Sonic、Unichain。

## 2. 关键地址

| 作用 | 链 | 地址 |
|---|---|---|
| **系统合约 SYSTEM**（订阅 / 回调请求 / 付费） | Lasna 与主网相同 | `0x8888888888888888888888888888888888888888` |
| Cron 事件发射地址（只用于 Cron 订阅的 `contract_`） | Lasna 与主网 | `0x0000000000000000000000000000000000fffFfF` |
| Callback Proxy | Ethereum Sepolia | `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4` |
| Callback Proxy | Base Sepolia | `0x476F44b11F5C942c58f4c8E3d0300E5710743585` |
| Callback Proxy | Unichain Sepolia | `0x775c9B990ADe401060B78D0e98684eEf8d2466C1` |
| Callback Proxy | Lasna（回调回 Reactive 自己） | `0x8888888888888888888888888888888888888888` |

> ⚠️ 2026-11 Omni 升级后测试网 Proxy 已全部更换。搜到的旧地址（`0xc9f3…`、`0xa6eA…`、`0x9299…`）**不会再投递**，回调合约用旧地址会静默收不到回调。以 [Origins & Destinations](https://dev.reactive.network/origins-and-destinations) 当前页为准。
| lREACT faucet | Ethereum Sepolia | `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434` |
| lREACT faucet | Base Sepolia | `0x2afaFD298b23b62760711756088F75B7409f5967` |

主网 Callback Proxy 地址见 [Origins & Destinations](https://dev.reactive.network/origins-and-destinations)，本营不用。

## 3. 领测试币

1. 领 Sepolia ETH：Google Cloud / Alchemy / QuickNode 任一 faucet。
2. 把 Sepolia ETH **转账**给 faucet 合约 `0x9b9BB25f…`，**1 ETH → 100 lREACT**，单笔不要超过 5 ETH（超出部分丢失）。0.01 ETH 就能换 1 lREACT，够跑完全部练习。
   ```bash
   cast send --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434 --value 0.01ether
   ```
3. 约 1 分钟后查 Lasna 余额：`cast balance <你的地址> -r https://lasna-rpc.rnk.dev/ -e`
4. 也可以 `request(address)` 给合约直接充值，或在 [ReacDEFI](https://reacdefi.app/markets#testnet-faucet) 兑换。

## 4. 费用模型（三个数）

| 数 | 含义 | 后果 |
|---|---|---|
| balance | 合约里的余额 | react() 和 callback 都从这里扣 |
| reserves | 预付 | 保证能支付 |
| **debt** | **欠款** | **只要 > 0，合约就收不到任何事件和回调（静默停止）** |

- Reactive 交易用 lREACT / REACT 支付，单笔 gas 上限 900k。实测一笔简单 react() 约 **0.015 lREACT**（Lasna gas price 100 gwei）。
- **Callback 由接收方在目标链用原生币（ETH）支付**，所以回调合约部署时要带 ETH；gas 下限 100k，低于会被忽略；**失败也收费**。
- react() 里 `revert` 不会省钱，照样收费 → 用 `return` 过滤。
- 欠费恢复：直接给合约转币，或调用 `coverDebt()`；查欠款 `cast call 0x8888… 'debt(address)(uint256)' <合约>`。

## 5. Omni 写法 vs 旧写法（AI 最容易写错的地方）

| | Omni（现在） | 旧版 ReactVM（**不要用**） |
|---|---|---|
| 依赖 | `Reactive-Network/reactive-lib-omni`，`import "@reactive/src/..."` | `reactive-lib` |
| Solidity | `^0.8.29` | 0.8.x |
| 系统合约 | `SYSTEM` = `0x8888…8888`（AbstractReactive 里已定义） | `0x…fffFfF` |
| react() 修饰符 | `onlySystem` | `vm` / `rnOnly` |
| 请求回调 | `SYSTEM.requestCallbackV_1_0(CallbackConfiguration_V_1_0{chainId, recipient, gasLimit, payload})` | `emit Callback(...)` |
| 执行环境 | 单一环境，标准 EVM | ReactVM + RN 双状态机 |
| 调试 | `cast run`、Reactscan、Blockscout | 专用 RVM RPC（已取消） |

硬规则：
- **payload 第一个参数必须是 `address`，填 `address(0)` 占位**，网络会替换成 Reactive 合约地址。回调合约用 `onlyCallbackSender(addr)` 校验它。官方说这是「最常见的出错点」。
- 回调合约方法同时加 `onlyServiceProvider`（msg.sender 必须是 Proxy）和 `onlyCallbackSender(reactive_)`。
- `_CALLBACK_SENDER` 是 immutable，**填错只能重新部署**。
- 一个合约不能同时是 Reactive 合约和回调合约。
- 订阅只支持等值匹配：链 `0`、合约 `address(0)`、topic `REACTIVE_IGNORE` 是通配符；至少一个条件要是具体值；`unsubscribe` 参数必须和订阅时完全一致，否则静默失败。
- 订阅存在节点里，合约读不回来，自己记好。
- Cron：`subscribe(block.chainid, 0x…fffFfF, CRONx_TOPIC_0, IGNORE, IGNORE, IGNORE)`。Cron1≈1s，Cron10≈10s，Cron100≈2min，Cron1000≈17min，Cron10000≈3h；**每个 tick 都收费**，留暂停开关。Topic 常量见 `starter/` 里引用的 omni Cron 示例。

## 6. 部署顺序（本仓库脚本就是按这个顺序）

```
① 源链部署事件源（真实项目里通常是别人的合约）
② Lasna 部署 Reactive 合约（带 lREACT）
③ 目标链部署回调合约（构造参数 = 本链 Proxy + ② 的地址，带 ETH）
④ 回 Lasna 调 setRecipient(③)
⑤ 源链触发事件 → 约 10–60 秒后目标链出现回调交易
```

## 7. 常用命令

```bash
# 事件签名 → topic0
cast keccak "Ping(address,uint256)"
# 看 Lasna 上 react() 有没有被调
cast call -r https://lasna-rpc.rnk.dev/ $REACTIVE_ADDR 'lastReactBlock()(uint256)'
# 查欠款
cast call -r https://lasna-rpc.rnk.dev/ 0x8888888888888888888888888888888888888888 'debt(address)(uint256)' $REACTIVE_ADDR
# 查目标链回调事件
cast logs -r $SEPOLIA_RPC_URL --address $CALLBACK_ADDR "Handled(address,uint256,uint256,uint256,uint256)" --from-block <起始块>
# 复现一笔交易的调用链（排错神器）
cast run -r https://lasna-rpc.rnk.dev/ <txHash>
# 合约验证（Sourcify）
forge verify-contract --verifier sourcify --chain-id 5318007 $REACTIVE_ADDR src/CampReactive.sol:CampReactive
```

## 8. 官方资料里的矛盾（遇到别慌）

1. **系统合约地址**：Mainnet/Lasna 页和 Economy 页仍写 `0x…fffFfF`；Reactive Contracts 页、迁移说明和 reactive-lib-omni 源码写 `0x8888…`。**以 `0x8888` 为准**，`fffFfF` 只在 Cron 订阅里出现。
2. **omni demo README 过时**：omni 分支实际只有 4 个 micro-demo（PingPong / CallbackSender+Recipient / Cron / Xfers）。止损、Aave 等大 demo 只在 main 分支且是旧写法。
3. **测试网 Callback Proxy 新旧地址并存**：legacy 文档和部分 README 仍是旧 Proxy（如 Sepolia `0xc9f3…`），旧合约还有代码但 Omni Lasna 已不经它投递。**以当前 Origins & Destinations 页为准**（本仓库 11/9 已用 Sepolia `0xAa14…` 实测回调到账）。
4. 赛道 1 网络：DoraHacks 页写「主网或 Lasna」，博客写「Lasna」。本营统一 Lasna。
5. `/hyperlane` 文档页基本是空的；`/legacy/*` 是旧版文档，AI 搜索最容易搜到，**明确不要用**。
