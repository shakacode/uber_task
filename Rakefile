# frozen_string_literal: true

require 'bundler/gem_tasks'

task default: %i[rubocop spec]

desc 'Run RuboCop'
task :rubocop do
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new
end

desc 'Run tests'
task :spec do
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)
end

RAILS_DUMMY_DIR = 'tmp/test/dummy/'

namespace :rails do
  desc 'Generate dummy rails application'
  task :generate_dummy_app, [:dir] do |_t, args|
    dummy_app_dir = args.fetch(:dir, RAILS_DUMMY_DIR)
    exit(0) if Dir.exist?(dummy_app_dir)

    system(
      "rails new #{dummy_app_dir} " \
      '--skip-git --skip-asset-pipeline --skip-action-cable ' \
      '--skip-action-mailer --skip-action-mailbox --skip-action-text ' \
      '--skip-active-record --skip-active-job --skip-active-storage ' \
      '--skip-javascript --skip-hotwire --skip-jbuilder ' \
      '--skip-test --skip-system-test --skip-bootsnap ',
    )
  end
end
