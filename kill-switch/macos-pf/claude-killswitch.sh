#!/bin/sh
# Claude 直连熔断：在物理网卡上拒绝 Anthropic 官方 IP 段。
# 走代理时，Claude 流量经 TUN 或本地代理端口进入代理核心，物理网卡上只出现发往节点的连接，不受影响。
# 用法：claude-killswitch.sh load | unload | status（需 root）
set -e
ANCHOR=com.apple/claude-killswitch
# 来源：https://platform.claude.com/docs/en/api/ip-addresses（2026-10-26 核对）
ANTH4=160.79.104.0/21
ANTH6=2607:6bc0::/48

case "$1" in
  load)
    # 每次加载重新枚举物理网卡，不依赖动态 utunN 编号；新插的网卡由 LaunchDaemon 的 WatchPaths 触发重载
    PHYS=$(networksetup -listallhardwareports | awk '/^Device:/{print $2}' | tr '\n' ' ')
    [ -n "$PHYS" ] || { echo "未找到物理网卡" >&2; exit 1; }
    printf '%s\n' \
      "phys = \"{ $PHYS}\"" \
      "block return out quick on \$phys inet  to $ANTH4" \
      "block return out quick on \$phys inet6 to $ANTH6" \
      | pfctl -q -a "$ANCHOR" -f -
    pfctl -q -E 2>/dev/null || true
    ;;
  unload)
    pfctl -q -a "$ANCHOR" -F all
    ;;
  status)
    pfctl -s info 2>/dev/null | head -1
    pfctl -a "$ANCHOR" -s rules
    ;;
  *)
    echo "用法：$0 load | unload | status" >&2; exit 2
    ;;
esac
