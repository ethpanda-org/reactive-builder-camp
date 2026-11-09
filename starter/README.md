# reactive-starter｜「事件 → react() → 回调」三步走模板

Clone 即用的最小 Reactive Omni 工程：三个合约 + 部署脚本 + 本地测试 + 链上核验脚本。跑通它，你就拿到了黑客松评审的第一道硬门槛——**链上可查的 Reactive 交易和它触发的回调**。

```
源链 CampOrigin.ping(value)          ①  emit Ping(who, value)
        │  Reactive 网络按订阅匹配
        ▼
Lasna CampReactive.react(log)        ②  value >= threshold ? 请求回调 : return
        │  Callback Proxy 投递
        ▼
目标链 CampCallback.onEvent(...)     ③  emit Handled(...)  ← 这笔交易哈希就是你的证据
```

## 0. 前置

- [Foundry](https://book.getfoundry.sh/getting-started/installation)：`forge --version` 能输出即可
- 一个**只用于测试**的钱包私钥
- Sepolia ETH（≥ 0.02）；其中 0.01 换成 lREACT（见 `../docs/cheatsheet.md` 第 3 节）

## 1. 安装与本地测试（不用联网、不用测试币）

```bash
git clone --recurse-submodules https://github.com/ethpanda-org/reactive-builder-camp && cd reactive-builder-camp/starter
forge install          # 拉取 forge-std 与 reactive-lib-omni
forge test -vv         # 8 个测试：订阅、鉴权、阈值、全链路、次数上限
```

测试里用 `vm.etch` 把一个 MockSystem 放到 `0x8888…8888`，用 MockProxy 模拟 Callback Proxy 注入 reactive 地址，所以**整条链路在本地就能跑通**；先在这里改逻辑、加断言，再上链。

## 2. 上链（Sepolia 作源链和目标链，Lasna 作 Reactive 侧）

```bash
cp .env.example .env   # 填 PRIVATE_KEY；其他默认值就是 Sepolia ↔ Lasna ↔ Sepolia
set -a; source .env; set +a

# ① 源链：事件源
forge script script/Deploy.s.sol:DeployOrigin   --rpc-url $SEPOLIA_RPC_URL --broadcast
#   → 把输出的 ORIGIN_ADDR 填进 .env，重新 source

# ② Lasna：Reactive 合约（默认预付 0.5 lREACT，阈值 100，最多处理 5 次）
forge script script/Deploy.s.sol:DeployReactive --rpc-url $LASNA_RPC_URL --broadcast
#   → REACTIVE_ADDR 填进 .env

# ③ 目标链：回调合约（默认带 0.02 ETH 付回调 gas）
forge script script/Deploy.s.sol:DeployCallback --rpc-url $SEPOLIA_RPC_URL --broadcast
#   → CALLBACK_ADDR 填进 .env

# ④ 回 Lasna 绑定回调地址
forge script script/Deploy.s.sol:SetRecipient   --rpc-url $LASNA_RPC_URL --broadcast

# ⑤ 触发！value=500 ≥ 阈值 100，会回调
forge script script/Deploy.s.sol:Ping           --rpc-url $SEPOLIA_RPC_URL --broadcast
```

等 10–60 秒，核验：

```bash
bash script/verify.sh
```

会打印三笔交易对应的信息：源链 Ping 事件、Lasna 上 `lastReactBlock`、目标链 `count` 和 `Handled` 事件。把三个哈希写进打卡 / 提交包。

### 实测记录（2026-11-09，Sepolia ↔ Lasna ↔ Sepolia）

| 步骤 | 链接 |
|---|---|
| ① Ping 事件 | https://sepolia.etherscan.io/tx/0xaff2c1dbdbc78504dd4d37c72c4301389d2ea1571c74d60d1e7bcc6f385cb8e2 |
| ② Lasna CampReactive | https://lasna.reactscan.net/address/0x0a36446976525961CF2d5cc62AEe1952619F24a3 |
| ③ 回调 Handled | https://sepolia.etherscan.io/tx/0x97b96b4ac850e68924fb9341f6612bc29f738cd7e8029b7519c02d001c9554a7 |

Ping 到回调落地约 1 个区块。

## 3. 改成你自己的项目

| 想改什么 | 改哪里 |
|---|---|
| 监听别人的合约（ERC-20 Transfer、Uniswap Sync…） | `DeployReactive` 里的 `originAddr` 和 `topic0`；`react()` 里的解码逻辑 |
| 条件 | `react()` 里 `value < threshold` 那一行 |
| 目标链动作 | `CampCallback.onEvent` 的函数体；payload 签名要同步改两边 |
| 目标链换成 Base / Unichain Sepolia | `.env` 的 `DEST_CHAIN_ID`、`CALLBACK_PROXY`、`SEPOLIA_RPC_URL` |
| 定时触发 | 订阅改成 Cron（见 cheatsheet 第 5 节） |

## 4. 常见报错

| 现象 | 原因 | 处理 |
|---|---|---|
| Lasna 上 `lastReactBlock` 一直是 0 | 订阅参数和真实事件对不上（chainId / 合约地址 / topic0 其一错了） | `cast keccak` 重新算 topic0；确认源链 chainId |
| react() 被调了，目标链没回调，回调合约 `count` 一直是 0 | **`CALLBACK_PROXY` 用了旧地址**（Omni 升级后测试网 Proxy 全换了，旧地址仍有代码但不再投递） | 对照 cheatsheet 第 2 节，用新 Proxy 重新部署 ③，再做 ④ |
| react() 被调了，目标链没回调 | 回调合约没余额 / `recipient` 没设 / value 低于阈值 | `verify.sh` 看 `remaining`、`debt`、`balance` |
| 回调 revert `CallbackNotAuthorized` | 部署回调合约时 `reactive_` 填错 | 只能重新部署 ③，再做 ④ |
| 回调 revert `NotAuthorized` | 不是 Proxy 调的，或 Proxy 地址填错 | 对照 cheatsheet 第 2 节 |
| 突然什么都不触发了 | 欠费 `debt > 0` | 给合约转 lREACT / ETH，或调 `coverDebt()` |
| 编译报 `@reactive/...` 找不到 | 没 `forge install` | `forge install Reactive-Network/reactive-lib-omni` |

## 5. 安全

- `.env` 已在 `.gitignore`；**不要**把私钥贴给任何人、任何 AI 工具，也不要写进打卡。
- 官方和助教不会私信索要私钥、助记词、「验证」或「空投」。开发者群里有大量假冒管理员的钓鱼机器人。
- 全营只用测试网与测试钱包。

## 状态

- 本地 `forge test`：8/8 通过（Solc 0.8.29，reactive-lib-omni v0.1.0）。
- 链上三步走实测：待完成；完成后此处会贴三笔交易的浏览器链接。
