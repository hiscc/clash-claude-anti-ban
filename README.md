# clash-claude-anti-ban

检查并加固两层防线：**代理运行期路径不变式**（杜绝“代理开着，但 Claude 走了预期外节点、禁区、直连、错区/大陆 DNS、IPv6 或 UDP/QUIC 旁路”），以及**本机网络层直连熔断**（代理未开、崩溃、TUN 断开、切换直连或规则漏配时，Claude 连接在系统防火墙层直接失败）。

本项目只关心最终可验证的结果：**使用 Claude 时，HTTPS、资产域、DNS、IPv4/IPv6、WebRTC 与 UDP/QUIC 不得暴露真实网络路径，且必须稳定锁定在用户批准的支持地区节点；不走代理时，本机无法向 Claude 官方网络发起连接。**

## AI 执行入口

把本项目链接交给能够读取本机配置并执行命令的 AI：

```text
请读取这个项目的 SKILL.md，全面排查并修复我的 Claude 代理与本机网络泄漏，安装或更新代理未运行时的系统防火墙直连熔断，并完成运行时与断代验收：
https://github.com/hiscc/clash-claude-anti-ban
```

AI 必须读取 [SKILL.md](SKILL.md)，按本机实际代理软件（Mihomo / Clash Verge Rev、ClashX Pro/XPro 等）与操作系统实施并做运行时验收；不能只返回教程、示例配置或未经执行的结论。

## 推荐目标状态

| 维度 | 推荐状态 | 含义 |
|---|---|---|
| 增强模式 / TUN | 开（劫持 UDP + TCP 53） | 接管不遵守系统代理的客户端（CLI/桌面端/IDE）与 DNS |
| 设为系统代理 | 关（验证 TUN 全覆盖后） | 避免与 TUN 重复接管、环境变量冲突或误判实际路径 |
| 出站模式 | 规则（Rule） | 保留国内直连、其他服务分流与多 AI 平台分区能力 |
| Claude 代理组 | **独立专用组** → 固定支持地区手选节点 | 与日常上网的“节点选择组”解耦，防止日常切到香港/自动测速时把后台 Claude 带偏 |
| 覆盖范围 | `claude.ai` / `claude.com` / `anthropic.com` / `claudeusercontent.com` + 官方 IP 段（`no-resolve`） | 防止 Artifacts/桥接域掉进 `MATCH/DIRECT`，防止纯 IP 连接绕过域名规则 |
| DNS | 按域名 `nameserver-policy` 经**同一 Claude 组**走加密 DNS | 业务和 DNS 同区同组，不走大陆/运营商 DNS，也不被其他服务（如 Google/美区）串区；若节点拒连纯 IP（`1.1.1.1`/`8.8.8.8`），改用域名型 DoH（如 `dns.twnic.tw` / `doh.opendns.com`） |
| IPv6 / UDP / QUIC / WebRTC | 代理接管或明确 `REJECT` + 浏览器策略 + 代理层境外 STUN 拦截 | 节点 `udp: false` 时不回落直连；Chrome 配 `disable_non_proxied_udp`，同时在代理层拦截境外公共 STUN UDP（兜住 Electron/Safari 且不误伤飞书/微信通话） |
| 客户端与系统环境 | 清理冲突代理环境变量、浏览器代理插件、iCloud 专用代理及残留旧守护进程 | 避免浏览器、Claude Code CLI、桌面端各走各的出口，制造同号双地并发 |
| 订阅更新防炸与单一信源 | 扩展脚本自动剔除下线/改名节点，零节点时 fail-closed 为 `REJECT`；GUI 接管字段不重复写入 | 订阅改名不会导致重载报错或回落直连，启动零“字段已被丢弃”警告 |
| 本机网络直连熔断 | OS 防火墙拦截 Anthropic 全部官方 IPv4/IPv6 段（可按需扩展至其他 AI 平台专用入口段） | 代理关闭/崩溃/卡死/TUN 断开/规则误走直连时，本机直连在内核层 2–3ms 立即失败 |

> 增强模式接管流量 ≠ 所有流量都走代理节点：规则模式仍按规则分流。`utunN` 是 macOS 动态接口号，配置不得依赖动态编号；在 Fake-IP 模式下，系统防火墙可直接全接口阻断 Anthropic 真实 IP 段，连带堵死共存 VPN 与手机热点旁路。

## 常见泄漏与风控隐患

| 情况 | 真实后果 |
|---|---|
| Claude 绑在日常“节点选择组”下 | 日常看内容顺手切到香港/测速组，后台 Claude 瞬间从不支持地区发起请求 |
| `claudeusercontent.com` 未加规则 | 掉入 `MATCH`（常见为 `DIRECT`），直接暴露本地真实 IP |
| GUI 全局配置（如 `config.yaml` / `dns_config.yaml`）覆盖脚本/Merge | 以为配置了 `ipv6: false` 和同区 DNS，实际运行时被静默覆盖，出现“HTTPS 台湾 + DNS 美国/大陆”割裂 |
| 仅封了 `160.79.104.0/21` 而漏掉 `153.61.224.0/22` / `153.61.208.0/20` | 本机直连熔断不完整（注意 `153.61.208.0/20` 止于 `.223.255`，不含 `153.61.224.0/22`），代理挂掉时部分入口仍可直连握手 |
| 只配了 Chrome WebRTC 策略、未拦代理层境外 STUN | Electron 桌面端（Claude Desktop）与 Safari 不读 Chrome 策略，若 `MATCH` 走 `DIRECT`，第三方 STUN UDP 仍会漏出真实公网 IP |
| 节点拒连纯 IP 导致 `1.1.1.1`/`8.8.8.8` DoH 报 EOF | 表面配置了加密 DNS，实际 `/dns/query` 全败；需换用域名型 DoH 并实测通过 |
| 机场订阅删减或改名节点 | 硬编码旧节点名的分组会导致 Mihomo 报 `proxy not exist` 重载失败，需脚本动态清洗且零节点时 `REJECT` |
| 用带本地 session/Cookie 的请求跨多节点测速 | 测试动作本身就会制造短时多 IP 登录风控信号；验收必须全程使用无鉴权公开端点 |
| 只按物理网卡写防火墙规则 | 代理挂掉但连着公司 VPN / Tailscale / USB 热点时，流量经其他接口绕过熔断 |
| 切节点、改规则或加载防火墙后未清存量连接/DNS 缓存 | 旧 TCP/HTTP2/WebSocket 长连接和 PF state 继续走旧出口，形成短时双地 IP 并发 |
| 机场单节点背后多落地轮询 | 节点名不变，实际出口 IP/ASN 每几分钟漂移一次 |
| `HTTP_PROXY` / SwitchyOmega / iCloud Private Relay / 旧客户端守护进程残留 | 不同客户端出口割裂，或后台持续写入大量报错日志 |
| 节点 `udp: false` 且无显式 `REJECT` | WebRTC / QUIC / UDP 回落 `DIRECT` |
| 浏览器自带 DoH / Async DNS / WebRTC / QUIC / ECH | 绕过代理核心的 DNS、SNI 嗅探或 UDP 约束 |
| 订阅更新覆盖本地修改 | 加固在自动更新或重启后静默失效 |
| `WatchPaths` 反复调用 `pfctl -E` | macOS PF 引用计数令牌泄漏，卸载后防火墙状态异常 |

## 本机网络层直连熔断（代理未运行时直接失败）

代理路径加固只在代理运行时生效。为了保证**不走代理时本机根本无法请求 Claude 相关网络**，AI 会在系统防火墙层（macOS 使用原生 `pf` 子锚点，不改动 `/etc/pf.conf`）对 Anthropic 官方发布的全部 IPv4/IPv6 段（以[官方文档](https://platform.claude.com/docs/en/api/ip-addresses)为准，2026-11 含 `160.79.104.0/21`、`153.61.224.0/22`、`153.61.208.0/20`、`2607:6bc0::/48`）实施出站阻断：

- **Fake-IP 模式下优先全接口阻断**：正常走代理时应用访问 `198.18.0.0/15`、代理核心连接代理节点 IP，均不向任何网卡发出目标为 Anthropic 真实 IP 的数据包；全接口阻断既无需硬编码动态 `utunN`，也能同时防住物理网卡、热点和共存 VPN 绕过。
- **清理存量连接状态 + 防止令牌泄漏**：加载锚点后清理 PF 存量 state（`pfctl -k`），并避免重复调用 `pfctl -E` 造成引用计数泄漏；开机自动生效，支持一键完整卸载。
- 即使当前本地网络本来就直连不通，也照样安装，让“无代理必失败”成为确定性结果。详见 [SKILL.md](SKILL.md) 的「Host-network kill switch」。

## 检测与验收

网页检测可参考 [Claude AI IP 风险检测](https://ip.net.coffee/claude/)（分享截图前请隐藏完整公网 IP），但**不能单靠单个第三方网页下结论**。AI 必须结合原生命令行与代理核心运行时 API（`/configs`、`/proxies`、`/connections`）逐项验收：

- 最终生效的运行时配置未被 GUI 全局文件覆盖（`mode: rule`、`ipv6`、`dns-hijack`、`sniffer`、策略组均与目标一致）；
- `claude.ai`、`api.anthropic.com`、`claudeusercontent.com` 均命中独立 Claude 组及支持地区具体节点，连续多次探测出口 IP/ASN 稳定无漂移；
- Claude 加密 DNS 连接命中**同一** Claude 组与节点，不出现大陆/本地运营商 DNS 或其他地区的串区 DNS；
- 不支持 UDP 的节点对 Claude UDP/QUIC 明确 `REJECT`，不回落 `DIRECT`；
- 已清理系统/浏览器 DNS 缓存与存量长连接，且无冲突环境变量、浏览器代理插件或残留旧守护进程；
- 重启代理与更新订阅后所有不变式依然成立；
- **本机熔断全段实测通过**：物理口直连 `160.79.104.10`、`153.61.224.1` 及 IPv6 段均立即失败，直连非 Anthropic 地址正常，**真正暂停代理**后无法请求 Claude，重启电脑后规则依然生效且无 `pfctl -E` 令牌泄漏。

> DNS 服务可能使用 Anycast，检测到的城市不必与节点城市逐字一致；但代理核心日志必须证明 DNS 传输走的是同一 Claude 节点，且未出现中国大陆、本地运营商或跨区串组解析路径。

本项目降低的是网络路径不一致与直连暴露带来的风控风险，不能保证账号永不受限。代理 IP 信誉、多设备跨区同时在线、Cookie、账号历史、设备指纹与平台政策仍会影响风控。

## 三层完整防护速查

要把封号和 IP 暴露风险压到最低，需同时守住 **节点选择 → 代理软件防护 → 本机防护** 三道关口：

### 1. 节点选择
- **固定 IP 优先于低延时**：先用无鉴权探测做「单轮多次 + 跨时段」复测，剔除背后多落地轮询的节点；AI 场景下稳定不断流（如 300–500ms）远胜低延时却频繁跳 IP 的节点。
- **排雷“IP 送中”与禁区**：常规 GeoIP 显示美国/台湾不代表模型 API 放行，共享机房段可能已被模型内部地理库标为 `CN`；严禁把香港、澳门、大陆、俄罗斯及自动测速组放进 Claude 专用组。
- **协议取舍**：固定宽带主力优先稳定的 TCP 代理节点（晚高峰不易被 UDP QoS 掐断导致长流式中断）；`TUIC` / `Hysteria` 等 UDP 协议可作移动弱网备选。
- **一号一 IP、多端对齐**：多账号之间尽量物理拆池不共用出口 IP；同一账号在电脑与手机（如 Clash Verge Rev + iOS Stash）上应同步精确白名单并选同一地区/同一节点，**绝不拿主力登录态短时连测多个节点**。
- **终极稳态**：若主力账号价值高且共享机场反复被用脏，建议单独配置独享静态 ISP/纯净 VPS 落地，只承接 AI 流量。

### 2. 代理软件防护
- **独立分组解耦**：给 Claude 建独立手选分组，与日常上网的“节点选择组”隔离，防止日常切节点误把后台 Claude 带进禁区。
- **全范围规则 + 兜底**：覆盖 `claude.ai`、`claude.com`、`anthropic.com`、`claudeusercontent.com` 以及 Anthropic 全部官方 IP 段（`IP-CIDR`/`IP-CIDR6` 带 `no-resolve`），开启 `sniffer` 并关闭 `ipv6`。
- **同区加密 DNS**：开启 `tun.dns-hijack`（UDP + TCP 53）并拒绝 `853` 端口；通过按域名 `nameserver-policy` 让 Claude 的加密 DNS 走同一 Claude 组（若节点拒连 `1.1.1.1`/`8.8.8.8` 等纯 IP，改用 `dns.twnic.tw` / `doh.opendns.com` 等域名型 DoH 并实测 `/dns/query`）。
- **UDP / QUIC / WebRTC STUN 封堵**：对 Claude 域名显式 `REJECT` UDP/QUIC，并对常见境外公共 STUN 服务器（如 `stun.cloudflare.com`、`stun*.l.google.com`、`stun.stunprotocol.org`）精准 `REJECT` UDP，兜住 Electron 桌面端与 Safari 旁路且不误伤国内音视频通话。
- **GUI 单一信源与订阅防炸**：避免 GUI 覆写与 Merge/Script 重复写 `dns`/`tun`/`ipv6` 引发静默丢弃；在订阅更新后自动剔除下线/改名节点名，零可用支持地区节点时 fail-closed 为 `REJECT`。

### 3. 本机防护
- **系统防火墙直连熔断（桌面端）**：macOS 用原生 `pf` 子锚点 + `table` 拦截全部官方 IP 段（Fake-IP 下全接口阻断，同时防住物理网卡、USB 热点与共存 VPN 旁路），配合 `pfctl -k` 清存量状态、避免 `pfctl -E` 令牌泄漏，并开机自动加载；Linux/Windows 用对应系统防火墙实现等效出站阻断。
- **浏览器与系统旁路收口**：Chromium 浏览器锁定 `WebRtcIPHandling = disable_non_proxied_udp`、`DnsOverHttpsMode = off`、`QuicAllowed = false`；关闭 iCloud 专用代理（Private Relay），清理冲突的 `HTTP_PROXY`/`NO_PROXY` 环境变量、浏览器代理插件及残留旧代理守护进程。
- **移动端兜底**：Android 开启系统级「始终开启 VPN + 阻止未经 VPN 的连接」；iOS（如 Stash）开启「按需连接（On-Demand）」、关闭 iCloud 专用代理，并通过精确白名单覆写保持与电脑端规则对齐。
- **切换卫生**：改规则或切节点后清系统/浏览器 DNS 缓存并断开存量 Claude 长连接；客户端层面可按需配置 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 减少非必要外连。

## License

MIT
