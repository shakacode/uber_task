# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'uber_task'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
