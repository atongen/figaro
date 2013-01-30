require "shellwords"
require "pathname"
require "figaro/env"
require "figaro/railtie" if defined?(::Rails)
require "figaro/tasks"

module Figaro
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
      dir = __FILE__
      begin
        dir = Pathname.new(File.expand_path(File.join(dir, '..')))
        if dir.entries.detect { |e| e.to_s == 'config.ru' }
          @path = dir.join("config/application.yml")
          break
        end
      end until dir.root?

      @path
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
end

if !defined?(::Rails)
  ENV.update(Figaro.env)
end
