#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h}
exec ruby "$project_dir/scripts/restore.rb" "$@"
