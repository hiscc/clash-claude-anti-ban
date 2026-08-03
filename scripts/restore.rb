#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'optparse'
require_relative 'common'

options = { app_home: nil, dry_run: false }
OptionParser.new do |parser|
  parser.on('--app-home PATH') { |value| options[:app_home] = value }
  parser.on('--dry-run') { options[:dry_run] = true }
end.parse!

home = ClashClaudeHardening.app_home(options[:app_home])
backup_root = File.join(home, 'clash-claude-anti-ban-backups')
backup_dir = Dir.glob(File.join(backup_root, '*')).select { |path| File.directory?(path) }.max
abort '没有可恢复的备份。' unless backup_dir

manifest = ClashClaudeHardening.load_yaml(File.join(backup_dir, 'manifest.yaml'), [])
puts "将恢复：#{backup_dir}"

manifest.each do |entry|
  relative = entry.fetch('path')
  target = File.join(home, relative)
  source = File.join(backup_dir, relative)
  puts "  - #{relative}"
  next if options[:dry_run]

  if entry['created']
    FileUtils.rm_f(target)
  else
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target, preserve: true)
  end
end

puts(options[:dry_run] ? 'dry-run 完成。' : '恢复完成。请重启 Clash Verge Rev。')
