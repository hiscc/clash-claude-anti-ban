#!/bin/sh
# 用法：sudo sh kill-switch/macos-pf/uninstall.sh
DIR="/Library/Application Support/claude-killswitch"
launchctl bootout system/io.github.hiscc.claude-killswitch 2>/dev/null
[ -f "$DIR/claude-killswitch.sh" ] && sh "$DIR/claude-killswitch.sh" unload
rm -rf "$DIR" /Library/LaunchDaemons/io.github.hiscc.claude-killswitch.plist
echo "claude-killswitch 已移除"
