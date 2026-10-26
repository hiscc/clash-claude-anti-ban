# macOS 代理未运行时熔断（pf）

代理软件没开、崩溃或 TUN 断开时，Claude 请求会直接从物理网卡出去，暴露真实网络路径。本模块用 macOS 自带防火墙 pf 拒绝这类连接。

## 原理

- 拦截目标：Anthropic 官方 IP 段 `160.79.104.0/21`、`2607:6bc0::/48`（[来源](https://platform.claude.com/docs/en/api/ip-addresses)，2026-10-26 核对）。按 IP 拦截，`claude.ai`、`claude.com`、`anthropic.com` 及子域都覆盖。
- 拦截位置：只在物理网卡（`networksetup -listallhardwareports` 列出的 Wi-Fi、有线、雷雳桥等）上 `block return`。代理开着时，Claude 流量进入 TUN 或本地代理端口，物理网卡上只有发往节点的连接，不受影响。
- 不依赖 `utunN` 编号，也不绑定具体代理软件。
- 规则挂在系统已有的 `com.apple/*` 锚点下（`com.apple/claude-killswitch`），不改 `/etc/pf.conf`。
- LaunchDaemon `io.github.hiscc.claude-killswitch` 开机加载；网络配置变化（新增网卡等）时重新枚举网卡并重载。

## 使用

```sh
sudo sh kill-switch/macos-pf/install.sh     # 安装，复制到 /Library/Application Support/claude-killswitch 与 /Library/LaunchDaemons
sh kill-switch/macos-pf/verify.sh           # 验证，无需 root，需代理开启
sudo sh kill-switch/macos-pf/uninstall.sh   # 卸载
```

`verify.sh` 期望输出：经代理访问 `claude.ai` / `api.anthropic.com` 有状态码（403/401 即连通）；从物理网卡直连 `160.79.104.10` 报 `Couldn't connect`；对照 `223.5.5.5` 有状态码。

## 局限

- 代理未运行时，系统仍会向本地 DNS 查询 Claude 域名；连接被拒，但查询本身可见。
- 只覆盖官方 IP 段；若 Anthropic 把某子域放到其他 CDN，该子域不受保护。
- 代理规则若把 Claude 分到 `DIRECT`，同样会被拒绝——这是预期行为，表现为开着代理也连不上 Claude，应修正代理规则而非卸载本模块。
