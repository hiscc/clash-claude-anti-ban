#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h}

if ! command -v ruby >/dev/null 2>&1; then
  print -u2 '缺少 Ruby。请先安装 Ruby，再重新运行。'
  exit 1
fi

exec ruby "$project_dir/scripts/install.rb" "$@"
