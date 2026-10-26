#!/bin/sh
# 用法：sudo sh kill-switch/macos-pf/install.sh
set -e
K="$(cd "$(dirname "$0")" && pwd)"
DIR="/Library/Application Support/claude-killswitch"
PLIST=/Library/LaunchDaemons/io.github.hiscc.claude-killswitch.plist
mkdir -p "$DIR"
install -m 755 -o root -g wheel "$K/claude-killswitch.sh" "$DIR/claude-killswitch.sh"
install -m 644 -o root -g wheel "$K/io.github.hiscc.claude-killswitch.plist" "$PLIST"
launchctl bootout system/io.github.hiscc.claude-killswitch 2>/dev/null || true
launchctl bootstrap system "$PLIST"
sleep 1
sh "$DIR/claude-killswitch.sh" status
