# frozen_string_literal: true

DUMMY_RAILS_APP_PATH = 'tmp/test/dummy/'

namespace :rails do
  desc 'Generate dummy rails application'
  task :generate_dummy_app, [:app_path] do |_t, args|
    app_path = args.fetch(:app_path, DUMMY_RAILS_APP_PATH)

    if Dir.exist?(app_path)
      puts "Using Rails application at #{app_path} for tests..."
      next
    end

    puts "Generating dummy Rails application at #{app_path}..."
    system(
      "rails new #{app_path} " \
      '--skip-git --skip-asset-pipeline --skip-action-cable ' \
      '--skip-action-mailer --skip-action-mailbox --skip-action-text ' \
      '--skip-active-record --skip-active-job --skip-active-storage ' \
      '--skip-javascript --skip-hotwire --skip-jbuilder ' \
      '--skip-test --skip-system-test --skip-bootsnap ',
    )
  end
end
