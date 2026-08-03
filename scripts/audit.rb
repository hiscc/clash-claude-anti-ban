#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require_relative 'common'

options = { app_home: nil }
OptionParser.new do |parser|
  parser.on('--app-home PATH') { |value| options[:app_home] = value }
end.parse!

home = ClashClaudeHardening.app_home(options[:app_home])
_profiles_path, _profiles, _items, current = ClashClaudeHardening.profiles_context(home)
_profile_path, profile = ClashClaudeHardening.current_profile_config(home, current)
groups = Array(profile['proxy-groups'])
proxy_group = ClashClaudeHardening.detect_proxy_group(groups)
errors = []

generated_path = File.join(home, 'clash-verge.yaml')
if File.exist?(generated_path)
  generated = ClashClaudeHardening.load_yaml(generated_path)
  effective_groups = Array(generated['proxy-groups'])
  direct_names = ClashClaudeHardening.direct_only_groups(effective_groups)
  violations = effective_groups.each_with_object([]) do |group, result|
    next if direct_names.include?(group['name'])

    members = Array(group['proxies'])
    bad = members.select { |member| member == 'DIRECT' || direct_names.include?(member) }
    result << [group['name'], bad] unless bad.empty? && group['empty-fallback'] != 'DIRECT'
  end

  errors << "非直连组仍可到达 DIRECT：#{violations.inspect}" unless violations.empty?
  errors << '当前不是 rule 模式' unless generated['mode'] == 'rule'
  errors << 'IPv6 未关闭' unless generated['ipv6'] == false
  errors << 'TUN strict-route 未开启' unless generated.dig('tun', 'strict-route') == true
  errors << 'DNS 未遵守规则' unless generated.dig('dns', 'respect-rules') == true

  nameservers = Array(generated.dig('dns', 'nameserver'))
  errors << "境外 DNS 未绑定 #{proxy_group}" unless nameservers.any? && nameservers.all? { |server| server.end_with?("##{proxy_group}") }

  required_rules = [
    "DOMAIN-SUFFIX,claude.ai,#{proxy_group}",
    "DOMAIN-SUFFIX,claude.com,#{proxy_group}",
    "DOMAIN-SUFFIX,anthropic.com,#{proxy_group}",
  ]
  errors << 'Claude 前置规则缺失' unless required_rules.all? { |rule| Array(generated['rules']).include?(rule) }
else
  errors << '找不到生成配置 clash-verge.yaml；请先重启 Clash Verge Rev'
end

verge = ClashClaudeHardening.load_yaml(File.join(home, 'verge.yaml'))
errors << '系统代理未开启' unless verge['enable_system_proxy'] == true
errors << 'Proxy Guard 未开启' unless verge['enable_proxy_guard'] == true
errors << 'PAC 仍包含 DIRECT 兜底' if verge['pac_file_content'].to_s.match?(/;\s*DIRECT\s*;/)

if errors.empty?
  puts "审计通过：#{current['name'] || current['file']} / #{proxy_group}"
  exit
end

warn '审计失败：'
errors.each { |error| warn "  - #{error}" }
exit 1
