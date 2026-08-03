#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
fixture_dir="$project_dir/test/fixtures/app-home"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/clash-claude-anti-ban-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

cp -R "$fixture_dir/." "$test_dir/"

CLASH_VERGE_HOME="$test_dir" "$project_dir/install.sh" --dry-run >/dev/null
CLASH_VERGE_HOME="$test_dir" "$project_dir/install.sh" >/dev/null

ruby -ryaml -e '
  home = ARGV.fetch(0)
  load_yaml = ->(path) { YAML.safe_load(File.read(path), permitted_classes: [Time], aliases: true, filename: path) }
  merge = load_yaml.call(File.join(home, "profiles", "merge.yaml"))
  rules = load_yaml.call(File.join(home, "profiles", "rules.yaml"))
  verge = load_yaml.call(File.join(home, "verge.yaml"))
  abort "mode" unless merge["mode"] == "rule"
  abort "ipv6" unless merge["ipv6"] == false
  abort "dns proxy" unless merge.dig("dns", "nameserver").all? { |server| server.end_with?("#openAI") }
  abort "strict route" unless merge.dig("tun", "strict-route") == true
  abort "Claude rules" unless rules["prepend"].first(3) == [
    "DOMAIN-SUFFIX,claude.ai,openAI",
    "DOMAIN-SUFFIX,claude.com,openAI",
    "DOMAIN-SUFFIX,anthropic.com,openAI",
  ]
  abort "PAC direct fallback" if verge["pac_file_content"].include?("DIRECT")
' "$test_dir"

node --check "$test_dir/profiles/script.js"
ruby -I"$project_dir/scripts" -rcommon -ryaml -rjson -e '
  home = ARGV.fetch(0)
  load_yaml = ->(path) { YAML.safe_load(File.read(path), permitted_classes: [Time], aliases: true, filename: path) }
  config = load_yaml.call(File.join(home, "profiles", "demo.yaml"))
  merge = load_yaml.call(File.join(home, "profiles", "merge.yaml"))
  rules = load_yaml.call(File.join(home, "profiles", "rules.yaml"))
  ClashClaudeHardening.deep_merge(config, merge)
  config["rules"] = Array(rules["prepend"]) + Array(config["rules"]) + Array(rules["append"])
  File.write(File.join(ARGV.fetch(0), "input.json"), JSON.generate(config))
' "$test_dir"

node -e "
  const fs = require('fs');
  const home = process.argv[1];
  const source = fs.readFileSync(home + '/profiles/script.js', 'utf8');
  eval(source);
  const config = JSON.parse(fs.readFileSync(home + '/input.json', 'utf8'));
  fs.writeFileSync(home + '/output.json', JSON.stringify(main(config, 'demo')));
" "$test_dir"

ruby -rjson -ryaml -e '
  config = JSON.parse(File.read(File.join(ARGV.fetch(0), "output.json")))
  groups = config.fetch("proxy-groups")
  direct = groups.select { |group| group["proxies"] == ["DIRECT"] }.map { |group| group["name"] }
  violations = groups.reject { |group| direct.include?(group["name"]) }.select do |group|
    Array(group["proxies"]).any? { |member| member == "DIRECT" || direct.include?(member) }
  end
  abort "DIRECT path remains: #{violations}" unless violations.empty?
  File.write(File.join(ARGV.fetch(0), "clash-verge.yaml"), YAML.dump(config))
' "$test_dir"

CLASH_VERGE_HOME="$test_dir" "$project_dir/audit.sh" >/dev/null

CLASH_VERGE_HOME="$test_dir" "$project_dir/install.sh" >/dev/null
backup_count=$(find "$test_dir/clash-claude-anti-ban-backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[[ "$backup_count" -eq 2 ]]

CLASH_VERGE_HOME="$test_dir" "$project_dir/restore.sh" >/dev/null

print 'all tests passed\n'
