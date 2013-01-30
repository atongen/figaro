require "shellwords"
require "pathname"
require "rbconfig"
require "figaro/env"
require "figaro/railtie" if defined?(::Rails)
require "figaro/tasks"

module Figaro

  class << self
    attr_accessor :called_from

    def extended(base)
      base.called_from = begin
        # Remove the line number from backtraces making sure we don't leave anything behind
        call_stack = caller.map { |p| p.sub(/:\d+.*/, '') }
        File.dirname(call_stack.detect { |p| p !~ %r[figaro] })
      end
    end
  end

  extend self

  def vars(custom_environment = nil)
    env(custom_environment).map { |key, value|
      "#{key}=#{Shellwords.escape(value)}"
    }.sort.join(" ")
  end

  def env(custom_environment = nil)
    environment = (custom_environment || self.environment).to_s
    Figaro::Env.from(stringify(flatten(raw).merge(raw.fetch(environment, {}))))
  end

  def raw
    @raw ||= yaml && YAML.load(yaml) || {}
  end

  def yaml
    @yaml ||= File.exist?(path) ? File.read(path) : nil
  end

  def path
    return @path if @path

    if defined?(::Rails)
      @path = Rails.root.join("config/application.yml")
    else
      # assumes config.ru in root of rack-based apps
      @path = find_root_with_flag("config.ru").join("config/application.yml")
    end
  end

  def environment
    ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
  end

  private

  def flatten(hash)
    hash.reject { |_, v| Hash === v }
  end

  def stringify(hash)
    hash.inject({}) { |h, (k, v)| h[k.to_s] = v.to_s; h }
  end

  def find_root_with_flag(flag, default=nil)
    root_path = self.called_from

    while root_path && File.directory?(root_path) && !File.exist?("#{root_path}/#{flag}")
      parent = File.dirname(root_path)
      root_path = parent != root_path && parent
    end

    root = File.exist?("#{root_path}/#{flag}") ? root_path : default
    raise "Could not find root path for #{self}" unless root

    (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/) ?
      Pathname.new(root).expand_path : Pathname.new(root).realpath
  end
end

if !defined?(::Rails)
  ENV.update(Figaro.env)
end
