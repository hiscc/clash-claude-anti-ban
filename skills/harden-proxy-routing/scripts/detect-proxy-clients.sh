#!/bin/zsh
set -u

running() {
  if pgrep -if "$1" >/dev/null 2>&1; then
    print 'yes'
    return
  fi

  if command -v lsof >/dev/null 2>&1 && lsof -nP 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -Eiq "$1"; then
    print 'yes'
    return
  fi

  print 'no'
}

installed_path() {
  [[ -e "$1" ]] && print 'yes' || print 'no'
}

print 'client\tinstalled\trunning\tconfig/app'

if [[ "$(uname -s)" == 'Darwin' ]]; then
  print "Clash Verge Rev\t$(installed_path '/Applications/Clash Verge.app')\t$(running 'clash-verge|verge-mihomo')\t$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
  print "ClashX Pro\t$(installed_path '/Applications/ClashX Pro.app')\t$(running 'ClashX|ClashX Pro')\t$HOME/.config/clash"
  print "Surge\t$(installed_path '/Applications/Surge.app')\t$(running '/Surge.app|Surge')\t$HOME/Library/Application Support"
else
  print "Mihomo/Clash\t$(command -v mihomo >/dev/null 2>&1 && print yes || print no)\t$(running 'mihomo|clash')\t${XDG_CONFIG_HOME:-$HOME/.config}"
fi

print "sing-box\t$(command -v sing-box >/dev/null 2>&1 && print yes || print no)\t$(running 'sing-box')\t${XDG_CONFIG_HOME:-$HOME/.config}/sing-box"
print "WireGuard\t$(command -v wg >/dev/null 2>&1 && print yes || print no)\t$(running 'wireguard|wg-quick')\t/system or app managed"
print "OpenVPN\t$(command -v openvpn >/dev/null 2>&1 && print yes || print no)\t$(running 'openvpn')\t/system or app managed"
print "Tailscale\t$(command -v tailscale >/dev/null 2>&1 && print yes || print no)\t$(running 'tailscaled|Tailscale')\t/system or app managed"

if command -v lsof >/dev/null 2>&1; then
  print '\ncommon local listeners'
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR == 1 || /:(7890|7891|9090|9097|6152|6153|1080|1087)( |$)/'
fi
