# frozen_string_literal: true

require 'rake'

class RailsManager
  APP_PATH = '../../tmp/test/dummy/'

  attr_reader :config, :app_path

  def initialize(config, app_path: APP_PATH)
    @config = config
    @app_path = app_path
  end

  def on_rails
    load_rails!
    yield
    unload_rails!
  end

  private

  def load_rails!
    return if defined?(Rails)

    if config.instance_variable_defined?(:@rails)
      Object.const_set(:Rails, config.instance_variable_get(:@rails))
      return
    end

    absolute_app_path = File.expand_path(app_path, __dir__)
    system("rake rails:generate_dummy_app[#{absolute_app_path}]")

    require File.expand_path(
      File.join(absolute_app_path, '/config/environment.rb'),
      __dir__,
    )

    ENV['RAILS_ROOT'] = absolute_app_path
    config.instance_variable_set(:@rails, Object.const_get(:Rails))
  end

  def unload_rails!
    ENV.delete('RAILS_ROOT')
    Object.send(:remove_const, :Rails)
  end
end
