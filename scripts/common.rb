# frozen_string_literal: true

require 'fileutils'
require 'date'
require 'yaml'

module ClashClaudeHardening
  APP_HOME = File.join(
    Dir.home,
    'Library',
    'Application Support',
    'io.github.clash-verge-rev.clash-verge-rev',
  )

  PREFERRED_PROXY_GROUPS = [
    'openAI',
    'PROXY',
    'Proxy',
    '代理',
    '节点选择',
    '🔰 节点选择',
  ].freeze

  module_function

  def app_home(explicit = nil)
    File.expand_path(explicit || ENV.fetch('CLASH_VERGE_HOME', APP_HOME))
  end

  def load_yaml(path, fallback = {})
    return Marshal.load(Marshal.dump(fallback)) unless File.exist?(path)

    YAML.safe_load(
      File.read(path),
      permitted_classes: [Time, Date, Symbol],
      aliases: true,
      filename: path,
    ) || Marshal.load(Marshal.dump(fallback))
  rescue Psych::SyntaxError => e
    abort "YAML 解析失败：#{path}\n#{e.message}"
  end

  def dump_yaml(value)
    YAML.dump(value).sub(/\A---\s*\n/, '')
  end

  def deep_merge(base, overlay)
    overlay.each do |key, value|
      base[key] = if base[key].is_a?(Hash) && value.is_a?(Hash)
                    deep_merge(base[key], value)
                  else
                    Marshal.load(Marshal.dump(value))
                  end
    end
    base
  end

  def profiles_context(home)
    profiles_path = File.join(home, 'profiles.yaml')
    abort "找不到 Clash Verge Rev 配置：#{profiles_path}" unless File.exist?(profiles_path)

    profiles = load_yaml(profiles_path)
    items = Array(profiles['items'])
    current = items.find { |item| item['uid'] == profiles['current'] }
    abort '找不到当前订阅配置。请先在 Clash Verge Rev 中选择一个订阅。' unless current

    [profiles_path, profiles, items, current]
  end

  def current_profile_config(home, current)
    filename = current['file']
    abort '当前配置没有本地 profile 文件。' if filename.to_s.empty?

    path = File.join(home, 'profiles', filename)
    abort "找不到当前 profile：#{path}" unless File.exist?(path)

    [path, load_yaml(path)]
  end

  def direct_only_groups(groups)
    Array(groups).select do |group|
      Array(group['proxies']) == ['DIRECT'] && Array(group['use']).empty?
    end.map { |group| group['name'] }.compact
  end

  def detect_proxy_group(groups, explicit = nil)
    group_list = Array(groups)
    direct_names = direct_only_groups(group_list)

    if explicit
      selected = group_list.find { |group| group['name'] == explicit }
      abort "找不到代理组：#{explicit}" unless selected
      abort "#{explicit} 是直连组，不能用于保护 Claude。" if direct_names.include?(explicit)
      abort '代理组名称不能包含逗号。' if explicit.include?(',')
      return explicit
    end

    names = group_list.map { |group| group['name'] }
    preferred = PREFERRED_PROXY_GROUPS.find { |name| names.include?(name) && !direct_names.include?(name) }
    return preferred if preferred

    candidates = group_list.select do |group|
      group['type'] == 'select' && !direct_names.include?(group['name']) && !group['name'].to_s.include?(',')
    end

    return candidates.first['name'] if candidates.length == 1

    abort '无法唯一判断安全代理组。请使用 --proxy-group 明确指定。'
  end

  def component_path(home, profiles, items, current, kind)
    current['option'] ||= {}
    uid = current['option'][kind]
    item = items.find { |entry| entry['uid'] == uid } if uid
    return [File.join(home, 'profiles', item['file']), false] if item && item['file']

    uid = "clashClaudeHardening#{kind.capitalize}"
    extension = kind == 'script' ? 'js' : 'yaml'
    filename = "#{uid}.#{extension}"
    item = {
      'uid' => uid,
      'type' => kind,
      'name' => 'clash-claude-anti-ban',
      'file' => filename,
      'updated' => Time.now.to_i,
    }
    items << item
    current['option'][kind] = uid
    profiles['items'] = items
    [File.join(home, 'profiles', filename), true]
  end

  def atomic_write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    mode = File.exist?(path) ? File.stat(path).mode & 0o777 : 0o600
    temporary = "#{path}.clash-claude-anti-ban.tmp"
    File.open(temporary, 'w', mode) { |file| file.write(content) }
    File.rename(temporary, path)
    File.chmod(mode, path)
  ensure
    FileUtils.rm_f(temporary) if defined?(temporary)
  end
end
