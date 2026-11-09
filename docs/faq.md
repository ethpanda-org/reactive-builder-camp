# Reactive Builder Camp｜FAQ（学员版）

> 发在 WCB 课程详情和社群公告里。问问题前先翻这里；没有答案再在群里问，附上：链、合约地址、交易哈希、报错原文。

## A. 测试币与环境

**Q1 Sepolia ETH 领不到 / 领得太少怎么办？**
Google Cloud、Alchemy、QuickNode 的 faucet 轮着试，一般每天各能领 0.05–0.1。全部练习只需要约 0.02 ETH：0.01 换 lREACT，剩下的付源链 / 目标链 gas。实在领不到，群里说一声，助教可以转 0.01。

**Q2 lREACT 怎么领？转了没到账？**
把 Sepolia ETH 直接转给 faucet 合约 `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`，1 ETH → 100 lREACT，**单笔不要超过 5 ETH**。约 1 分钟到账，查 `cast balance <地址> -r https://lasna-rpc.rnk.dev/ -e`。10 分钟没到：确认转的是 Ethereum Sepolia（不是 Base Sepolia，那条链的 faucet 是另一个地址）。

**Q3 钱包余额显示 0，但链上查得到？**
11/2 官方已确认是迁移后的显示 bug，修复中。用 `cast balance` 或 Reactscan 查链上真实余额。

**Q4 Foundry 装不上 / Windows 怎么办？**
Windows 用 WSL2 装 Ubuntu 再装 Foundry。macOS / Linux：`curl -L https://foundry.paradigm.xyz | bash && foundryup`。国内网络下 `forge install` 慢，可以先 `git clone` 到 `lib/` 再 `forge build`。

## B. 代码与部署

**Q5 AI 写出来的代码报 `vm` 修饰符、`emit Callback`、`0x…fffFfF`？**
那是旧版 ReactVM 写法，AI 训练数据里全是它。把第 0 周「给 AI 的上下文」那段话贴给 AI，并只参考 Omni 文档和 omni 分支示例。模板仓库 `starter/` 就是正确写法。

**Q6 `react()` 没有被调用（Lasna 上 lastReactBlock 一直是 0）？**
99% 是订阅没匹配上。逐项核对：源链 chainId（Sepolia 是 11155111）、合约地址大小写无关但要完整、`topic0 = cast keccak "事件签名(类型,类型)"`（签名里不能有参数名和空格）。订阅存在节点里读不回来，所以只能对照部署时的参数。

**Q7 react() 被调了，但目标链没有回调？**
按顺序查：⓪ **回调合约构造用的 Proxy 是不是当前地址**（速查表第 2 节；用了旧 Proxy 时，回调交易其实已经发到目标链，但被你的合约拒绝，表现就是「什么都没发生」，这是我们自己实测踩到的坑）；① 回调合约有没有 ETH（回调由接收方付费）；② Reactive 合约的 `recipient` 是否已 set；③ payload 第一个参数是不是 `address(0)` 占位；④ `cast call 0x8888… 'debt(address)(uint256)' <reactive>` 是否 > 0；⑤ gasLimit 是否 ≥ 100k。`cast run <Lasna 的 react 交易哈希>` 能看到有没有发出 CallbackRequested。

**Q8 回调交易 revert 了？**
`CallbackNotAuthorized` → 回调合约构造时的 reactive 地址填错，只能重新部署；`NotAuthorized` → 不是 Proxy 调的，或 Proxy 地址用错链。两道校验是故意设的，别为了跑通而删掉。

**Q9 合约突然「死」了，什么都不触发？**
八成是欠费（debt > 0）。给合约转 lREACT（Reactive 侧）或 ETH（目标链侧），或调用 `coverDebt()`。react() 里 revert 也照样扣费，所以不满足条件要用 `return`。

**Q10 Cron 怎么选间隔？**
Cron1≈1 秒、Cron10≈10 秒、Cron100≈2 分钟、Cron1000≈17 分钟、Cron10000≈3 小时；按区块节奏，不是精确墙钟。**每个 tick 都收费**，练习用 Cron100 以上，并写 pause()。

## C. 任务、打卡与补交

**Q11 打卡怎么打？**
在自己的 GitHub 学习仓库 `notes/` 下按日期写一个 md：今天做了什么、卡在哪、交易哈希。WCB 任务里贴这个文件的链接。

**Q12 错过了某天 / 第一周没跟上，还能参加吗？**
能。本营**不设强制出勤，也不会移出任何人**，任何时候补交都算。结业只看两个必做任务（跨链回调三步走、端到端骨架）和 600 核心分。

**Q13 Online Session 没赶上？**
每期都有回放，「参与或回看」任务看回放也算。

**Q14 补交截止是什么时候？**
WCB 任务都可以补交到 11/29 结营；Demo Day 回放笔记延长到 12/2 23:59；营内收提交包到 12/5 23:59。

## D. 黑客松提交

**Q15 在 WCB 完成任务就算报名黑客松了吗？**
不算。黑客松要自己在 [DoraHacks](https://dorahacks.io/hackathon/reactive-omni-buildathon/detail) 报名并提交 BUIDL。建议 D6（11/21）就先去报名。

**Q16 提交要准备什么？**
公开开源仓库、已部署合约地址、覆盖「源链事件 → Reactive 执行 → 目标链回调」的交易哈希、**不超过 3 分钟**的演示视频。赛道 1 另附全链路延迟实测；赛道 3 说明 AI 在运行时做什么决定。

**Q17 可以交几个赛道？可以用旧项目吗？**
官方答复：同一人可以给 3 个赛道各交一个项目。作品必须在活动期间（11/5 起）构建，旧成果只能作为依赖。

**Q18 截止时间？**
官方：12/5 20:00 UTC = **北京时间 12/6 04:00**。建议 12/4 前交，别卡最后一天。

**Q19 赛道 1 的「延迟实测」怎么测才算数？**
记三个区块时间戳：源链事件所在区块、Lasna 上 react() 交易所在区块、目标链回调交易所在区块。端到端 = 第三个 − 第一个；分段 = 相邻两个之差。至少测 5 次取中位数，写明用的链和 RPC。只写「大约 1 秒」不算。

## E. 安全

**Q20 有人私信说是管理员 / 让我「验证」/ 领空投？**
全是骗子。官方（Reactive、ETHPanda、助教）**从不先私信**，更不会要私钥、助记词、签名。开发者群里有大量假冒 Combot 的钓鱼机器人，看到直接举报。

**Q21 可以用主钱包吗？**
不要。新建一个只用于本期的钱包，全营只用测试网。私钥不进 Git、不进打卡、不贴给 AI。
