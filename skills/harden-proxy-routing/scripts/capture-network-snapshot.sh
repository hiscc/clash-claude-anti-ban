#!/bin/zsh
set -u

print '# Network snapshot'
print "os: $(uname -s) $(uname -r)"

if [[ "$(uname -s)" == 'Darwin' ]]; then
  print '\n## System proxy'
  scutil --proxy 2>/dev/null || true

  print '\n## DNS nameservers'
  scutil --dns 2>/dev/null | awk '/resolver #|nameserver\[[0-9]+\]|if_index|flags/'

  print '\n## Tunnel and public interfaces'
  ifconfig 2>/dev/null | awk '/^(utun|en[0-9]+):|^[[:space:]]+inet6? /'
else
  print '\n## Routes'
  ip route 2>/dev/null || true
  ip -6 route 2>/dev/null || true

  print '\n## DNS'
  resolvectl status 2>/dev/null || cat /etc/resolv.conf 2>/dev/null || true
fi

print '\n## Public egress (sensitive: redact before sharing)'
if command -v curl >/dev/null 2>&1; then
  ipv4=$(curl -4 -fsS --max-time 8 https://api.ipify.org 2>/dev/null || print unavailable)
  ipv6=$(curl -6 -fsS --max-time 8 https://api64.ipify.org 2>/dev/null || print unavailable)
  print "ipv4: $ipv4"
  print "ipv6: $ipv6"
else
  print 'curl unavailable'
fi
