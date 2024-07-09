# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter %r{^/tmp/}
end

require 'uber_task'
require 'colorize'

require_relative 'support/rails_manager'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around(:example, :on_rails) do |example|
    RailsManager.new(config).on_rails { example.run }
  end
end
