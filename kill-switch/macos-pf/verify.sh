#!/bin/sh
# 用法：sh kill-switch/macos-pf/verify.sh（无需 root，需代理处于开启状态）
IF=""
for d in $(networksetup -listallhardwareports | awk '/^Device:/{print $2}'); do
  ipconfig getifaddr "$d" >/dev/null 2>&1 && { IF=$d; break; }
done
[ -n "$IF" ] || { echo "没有已联网的物理网卡"; exit 1; }
echo "== 经代理访问（有状态码即连通，403/401 正常）"
curl -s -o /dev/null -m 15 -w "claude.ai          HTTP %{http_code}\n" https://claude.ai
curl -s -o /dev/null -m 15 -w "api.anthropic.com  HTTP %{http_code}\n" https://api.anthropic.com/v1/models
echo "== 绕过代理从 $IF 直连 Anthropic IP（应为 Couldn't connect）"
curl -sS -k -o /dev/null -m 10 --interface "$IF" -w "HTTP %{http_code}\n" https://160.79.104.10 2>&1
echo "== 对照：从 $IF 直连非 Anthropic IP（应有状态码）"
curl -sS -k -o /dev/null -m 10 --interface "$IF" -w "223.5.5.5 HTTP %{http_code}\n" https://223.5.5.5 2>&1
