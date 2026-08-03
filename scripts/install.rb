#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'optparse'
require 'time'
require_relative 'common'

include ClashClaudeHardening

options = {
  app_home: nil,
  dry_run: false,
  proxy_group: nil,
}

OptionParser.new do |parser|
  parser.banner = '用法：./install.sh [options]'
  parser.on('--app-home PATH', 'Clash Verge Rev 配置目录') { |value| options[:app_home] = value }
  parser.on('--proxy-group NAME', 'Claude 与境外 DNS 使用的代理策略组') { |value| options[:proxy_group] = value }
  parser.on('--dry-run', '只显示计划，不写文件') { options[:dry_run] = true }
  parser.on('-h', '--help', '显示帮助') do
    puts parser
    exit
  end
end.parse!

home = ClashClaudeHardening.app_home(options[:app_home])
profiles_path, profiles, items, current = ClashClaudeHardening.profiles_context(home)
_profile_path, profile = ClashClaudeHardening.current_profile_config(home, current)
groups = Array(profile['proxy-groups'])
proxy_group = ClashClaudeHardening.detect_proxy_group(groups, options[:proxy_group])

merge_path, merge_created = ClashClaudeHardening.component_path(home, profiles, items, current, 'merge')
rules_path, rules_created = ClashClaudeHardening.component_path(home, profiles, items, current, 'rules')
script_path, script_created = ClashClaudeHardening.component_path(home, profiles, items, current, 'script')

merge = ClashClaudeHardening.load_yaml(merge_path)
dns = {
  'enable' => true,
  'ipv6' => false,
  'enhanced-mode' => 'fake-ip',
  'fake-ip-range' => '198.18.0.1/16',
  'fake-ip-filter-mode' => 'blacklist',
  'prefer-h3' => false,
  'respect-rules' => true,
  'use-hosts' => false,
  'use-system-hosts' => false,
  'default-nameserver' => [
    'https://223.5.5.5/dns-query',
    'https://1.1.1.1/dns-query',
  ],
  'nameserver' => [
    "https://1.1.1.1/dns-query##{proxy_group}",
    "https://8.8.8.8/dns-query##{proxy_group}",
  ],
  'nameserver-policy' => {
    'geosite:private' => [
      'https://223.5.5.5/dns-query#DIRECT',
      'https://223.6.6.6/dns-query#DIRECT',
    ],
    'geosite:cn' => [
      'https://223.5.5.5/dns-query#DIRECT',
      'https://223.6.6.6/dns-query#DIRECT',
    ],
  },
  'proxy-server-nameserver' => [
    'https://223.5.5.5/dns-query#DIRECT',
    'https://223.6.6.6/dns-query#DIRECT',
  ],
  'direct-nameserver' => [
    'https://223.5.5.5/dns-query#DIRECT',
    'https://223.6.6.6/dns-query#DIRECT',
  ],
  'direct-nameserver-follow-policy' => true,
  'fallback' => [],
}

merge_overlay = {
  'mode' => 'rule',
  'ipv6' => false,
  'profile' => {
    'store-selected' => true,
    'store-fake-ip' => true,
  },
  'tun' => {
    'enable' => true,
    'stack' => 'gvisor',
    'auto-route' => true,
    'auto-detect-interface' => true,
    'strict-route' => true,
    'dns-hijack' => ['any:53', 'tcp://any:53'],
  },
  'dns' => dns,
}
ClashClaudeHardening.deep_merge(merge, merge_overlay)

rules = ClashClaudeHardening.load_yaml(rules_path, { 'prepend' => [], 'append' => [], 'delete' => [] })
protected_rules = [
  "DOMAIN-SUFFIX,claude.ai,#{proxy_group}",
  "DOMAIN-SUFFIX,claude.com,#{proxy_group}",
  "DOMAIN-SUFFIX,anthropic.com,#{proxy_group}",
  "DOMAIN-SUFFIX,cloudflare-dns.com,#{proxy_group}",
  "DOMAIN-SUFFIX,dns.google,#{proxy_group}",
  "DOMAIN-SUFFIX,alidns.com,#{proxy_group}",
  "DOMAIN-SUFFIX,doh.pub,#{proxy_group}",
  "IP-CIDR,1.1.1.1/32,#{proxy_group},no-resolve",
  "IP-CIDR,1.0.0.1/32,#{proxy_group},no-resolve",
  "IP-CIDR,8.8.8.8/32,#{proxy_group},no-resolve",
  "IP-CIDR,8.8.4.4/32,#{proxy_group},no-resolve",
  "IP-CIDR,223.5.5.5/32,#{proxy_group},no-resolve",
  "IP-CIDR,223.6.6.6/32,#{proxy_group},no-resolve",
  "IP-CIDR,119.29.29.29/32,#{proxy_group},no-resolve",
  "IP-CIDR,1.12.12.12/32,#{proxy_group},no-resolve",
  "IP-CIDR,120.53.53.53/32,#{proxy_group},no-resolve",
]
rules['prepend'] = protected_rules + Array(rules['prepend']).reject { |rule| protected_rules.include?(rule) }
rules['append'] ||= []
rules['delete'] ||= []

marker = '// clash-claude-anti-ban:v1'
original_script = File.exist?(script_path) ? File.read(script_path) : ''

unless original_script.include?(marker)
  renamed_script = if original_script.strip.empty?
                     ''
                   elsif original_script.match?(/\bfunction\s+main\s*\(/)
                     original_script.sub(/\bfunction\s+main\s*\(/, 'function __clashClaudeOriginalMain(')
                   else
                     abort "无法安全包裹原 Script：#{script_path}\n请先把 Script 改为 function main(config, profileName) 形式。"
                   end

  original_call = renamed_script.empty? ? 'config' : '__clashClaudeOriginalMain(config, profileName) || config'
  original_script = <<~JAVASCRIPT
    #{marker}
    // 由安装器生成：保留原 Script，再强制执行 fail-closed 清洗。
    #{renamed_script.rstrip}

    function __clashClaudeHardenGroups(config) {
      const groups = Array.isArray(config['proxy-groups']) ? config['proxy-groups'] : [];
      const directOnlyGroups = new Set(
        groups
          .filter(group => Array.isArray(group.proxies) && group.proxies.length === 1 && group.proxies[0] === 'DIRECT' && (!Array.isArray(group.use) || group.use.length === 0))
          .map(group => group.name),
      );

      for (const group of groups) {
        if (directOnlyGroups.has(group.name)) continue;

        if (Array.isArray(group.proxies)) {
          group.proxies = group.proxies.filter(member => member !== 'DIRECT' && !directOnlyGroups.has(member));
          const hasProvider = Array.isArray(group.use) && group.use.length > 0;
          if (group.proxies.length === 0 && !hasProvider) group.proxies = ['REJECT'];
        }

        if (group['empty-fallback'] === 'DIRECT') group['empty-fallback'] = 'REJECT';
      }

      return config;
    }

    function main(config, profileName) {
      const originalConfig = #{original_call};
      return __clashClaudeHardenGroups(originalConfig);
    }
  JAVASCRIPT
end

dns_path = File.join(home, 'dns_config.yaml')
dns_config = ClashClaudeHardening.load_yaml(dns_path, { 'dns' => {}, 'hosts' => {} })
dns_defaults = {
  'listen' => ':53',
  'fake-ip-filter' => [
    '*.lan',
    '*.local',
    '*.arpa',
    'time.*.com',
    'ntp.*.com',
    'localhost.ptlogin2.qq.com',
    '*.msftncsi.com',
    'www.msftconnecttest.com',
  ],
}
ClashClaudeHardening.deep_merge(dns_config['dns'] ||= {}, dns_defaults)
ClashClaudeHardening.deep_merge(dns_config['dns'], dns)

verge_path = File.join(home, 'verge.yaml')
verge = ClashClaudeHardening.load_yaml(verge_path)
ClashClaudeHardening.deep_merge(verge, {
  'enable_tun_mode' => true,
  'enable_system_proxy' => true,
  'enable_proxy_guard' => true,
  'enable_dns_settings' => true,
  'proxy_auto_config' => false,
  'pac_file_content' => <<~PAC,
    function FindProxyForURL(url, host) {
      return "PROXY 127.0.0.1:%mixed-port%; SOCKS5 127.0.0.1:%mixed-port%;";
    }
  PAC
})

profiles_changed = merge_created || rules_created || script_created
targets = {
  merge_path => ClashClaudeHardening.dump_yaml(merge),
  rules_path => ClashClaudeHardening.dump_yaml(rules),
  script_path => original_script,
  dns_path => ClashClaudeHardening.dump_yaml(dns_config),
  verge_path => ClashClaudeHardening.dump_yaml(verge),
}
targets[profiles_path] = ClashClaudeHardening.dump_yaml(profiles) if profiles_changed

puts "当前配置：#{current['name'] || current['file']}"
puts "安全代理组：#{proxy_group}"
puts "将修改："
targets.each_key { |path| puts "  - #{path}" }

if options[:dry_run]
  puts 'dry-run 完成，未写入任何文件。'
  exit
end

timestamp = Time.now.strftime('%Y%m%d-%H%M%S-%6N')
backup_root = File.join(home, 'clash-claude-anti-ban-backups')
backup_dir = File.join(backup_root, timestamp)
FileUtils.mkdir_p(backup_dir, mode: 0o700)
File.chmod(0o700, backup_root) if File.exist?(backup_root)
manifest = []

targets.each_key do |path|
  relative = path.delete_prefix("#{home}/")
  existed = File.exist?(path)
  manifest << { 'path' => relative, 'created' => !existed }
  next unless existed

  destination = File.join(backup_dir, relative)
  FileUtils.mkdir_p(File.dirname(destination), mode: 0o700)
  FileUtils.cp(path, destination, preserve: true)
end

ClashClaudeHardening.atomic_write(File.join(backup_dir, 'manifest.yaml'), ClashClaudeHardening.dump_yaml(manifest))
targets.each { |path, content| ClashClaudeHardening.atomic_write(path, content) }

puts "安装完成。备份：#{backup_dir}"
puts '请完全退出并重新启动 Clash Verge Rev，然后运行 ./audit.sh。'
