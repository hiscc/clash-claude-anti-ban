# clash-claude-anti-ban

一套交给 AI 使用的代理泄漏诊断与实施规范：不限定 AI 如何实现，只以最终网络流量是否仍能旁路为验收对象。仓库同时保留 Clash Verge Rev 参考实现。

它解决的不是“恶意后门”，而是代理软件常见的 **fail-open / DNS 旁路泄漏路径**：网页已经从海外代理出站，DNS、IPv6、浏览器 DoH 或策略组兜底却仍可能直连。

## 安全目标

- 保留规则模式：局域网和国内流量仍可由明确规则直连。
- Claude 与 Anthropic 域名始终进入指定代理策略组。
- 境外 DNS 通过同一个代理策略组发出，避免 IP 与 DNS 地域分裂。
- 除独立直连组外，任何代理组都不能包含 `DIRECT` 或引用直连组。
- 代理不可用时连接失败，不自动回退直连。
- TUN 劫持 TCP/UDP 53，关闭 IPv6 DNS，系统代理 PAC 不含 `DIRECT` 兜底。
- 所有修改先备份，可一键恢复。

## 推荐用法：让你的 AI 实施

把仓库中的 [`harden-proxy-routing`](skills/harden-proxy-routing/SKILL.md) Skill 交给 Codex、Claude Code 或其他能读取本机配置的 AI。它负责指导 AI：

1. 只读识别代理客户端、版本、活动配置和泄漏类型；
2. 根据真实客户端设计改动，不猜配置字段；
3. 先备份，再由 AI 实现客户端专用方案；
4. 重启后逐项验收，结果只能标为 `PASS`、`FAIL` 或 `NOT TESTED`；
5. 失败时恢复备份。

Skill 自身不会假装已经配置好机器，也不内置“一套写遍所有代理软件”的危险逻辑。只读探测脚本可以直接使用；所有写配置动作由使用者的 AI 根据现场实现。

只有受保护流量的 IPv4、IPv6、DNS/DoH/DoT、WebRTC/STUN、UDP/QUIC、应用旁路、故障回退和订阅更新持久性全部实测通过，才允许结论写“网络泄漏已解决”。配置已保存或客户端已重启都不算验收。

## Clash Verge Rev 参考实现

根目录脚本是 macOS Clash Verge Rev 的可运行参考，不是跨客户端通用安装器。运行前应让 AI 对照本机版本、活动配置和订阅生命周期检查代码；其他代理软件只能参考设计，不能直接套用。

## 边界

本项目不会提供节点、订阅或账号，也不能保证任何平台永不封禁。使用前需要：

1. macOS；
2. 已安装 Clash Verge Rev；
3. 已导入一个有效订阅；
4. Ruby（macOS 自带或 Homebrew 安装）。

## 参考实现的运行方式

```bash
git clone https://github.com/hiscc/clash-claude-anti-ban.git
cd clash-claude-anti-ban
./install.sh --dry-run
./install.sh
```

不知道当前运行的是哪个客户端时，先执行只读探测：

```bash
./skills/harden-proxy-routing/scripts/detect-proxy-clients.sh
./skills/harden-proxy-routing/scripts/capture-network-snapshot.sh
```

参考实现会自动选择 `openAI`、`PROXY`、`代理`、`节点选择` 等常见非直连策略组。无法可靠判断时会停止，不会默默选错。也可以明确指定：

```bash
./install.sh --proxy-group openAI
```

安装后完全退出并重新启动 Clash Verge Rev，再运行：

```bash
./audit.sh
```

最后用以下网站交叉验证：

- <https://ip.net.coffee/dns/>：先做深度测试；
- <https://browserleaks.com/dns>：复核浏览器自己的 DoH；
- <https://dnsleaktest.com/>：运行 Extended test。

合格标准不是“DNS 必须和代理同城”，而是 Claude/海外请求不出现本地运营商或中国大陆递归 DNS，且代理断开时受保护流量直接失败。

## 恢复

```bash
./restore.sh
```

恢复最近一次安装前的配置，然后重启 Clash Verge Rev。

## 工作原理

```text
Claude 请求 ──规则──> AI 代理组 ──> 实际代理节点
海外 DNS  ──DoH───> 同一 AI 代理组 ──> Cloudflare / Google DNS
国内域名  ──DoH───> 明确的 DIRECT DNS（仅国内直连规则）
代理故障  ─────────> REJECT / 连接失败，禁止 DIRECT 兜底
```

该参考实现只修改 Clash Verge Rev 的持久 Merge、Rules、Script 和全局 DNS 设置，不修改远程订阅正文。是否适配当前版本仍须由使用者的 AI 检查并完成运行时验收。详细威胁模型见 [docs/threat-model.md](docs/threat-model.md)。

## 开发与验证

```bash
./test/run.sh
```

测试覆盖自动探测、备份、配置合并、Script 包裹、非直连组清洗、重复安装和恢复。

## Agent Skill

[`harden-proxy-routing`](skills/harden-proxy-routing/SKILL.md) Skill 用于让 Codex/Claude Code：

- 自动识别代理客户端与泄漏类型；
- 按 adapter contract 现场设计和实现安全的配置路径；
- 解释检测结果，而不是把“看到 DNS”误判为泄漏；
- 执行统一的 IP、DNS、IPv6、WebRTC、路由日志和 fail-closed 验证，并输出明确验收状态。

Clash Verge Rev 代码仅作参考实现；ClashX Pro 提供检测和迁移判断；Surge、sing-box、WireGuard/OpenVPN、Tailscale 与移动端客户端提供诊断思路及 adapter 规范。具体实现始终由使用者的 AI 对照当前客户端完成。支持矩阵见 [Skill reference](skills/harden-proxy-routing/references/client-matrix.md)，验收标准见 [verification protocol](skills/harden-proxy-routing/references/verification-protocol.md)。

## 许可证

MIT
