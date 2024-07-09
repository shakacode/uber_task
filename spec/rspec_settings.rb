# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'uber_task'
require 'colorize'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.define_derived_metadata(file_path: %r{spec/on_rails}) do |metadata|
    metadata[:on_rails] = true
  end

  config.around(:example, :on_rails) do |example|
    require 'rake'
    load File.expand_path('on_rails/support/tasks/rails.rake', __dir__)

    rails_app_path = File.expand_path('../tmp/test/dummy/', __dir__)
    Rake::Task['rails:generate_dummy_app'].invoke(rails_app_path)

    require File.expand_path(
      File.join(rails_app_path, '/config/environment.rb'),
      __dir__,
    )

    ENV['RAILS_ROOT'] = rails_app_path
    raise 'Failed to load Rails application' unless defined?(Rails)

    example.run
  end
end
