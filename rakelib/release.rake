# frozen_string_literal: true

desc <<~DESC
  Release the gem with the given version.

  This task depends on the gem-release gem (included in development dependencies).

  Arguments:
    version: Can be 'patch', 'minor', 'major', or an explicit version (e.g., '0.2.0' or '0.2.0.beta.1')
    dry_run: Pass 'true' to perform a dry run without actually releasing

  Environment variables:
    VERBOSE=1 - Enable verbose logging
    RUBYGEMS_OTP=<code> - RubyGems one-time password (avoids prompts)
    GEM_RELEASE_MAX_RETRIES=<n> - Override max retry attempts (default: 3)

  Examples:
    rake release[patch]           # Bump patch version and release
    rake release[minor]           # Bump minor version and release
    rake release[major]           # Bump major version and release
    rake release[0.2.0]           # Set explicit version and release
    rake release[0.2.0.beta.1]    # Pre-release version
    rake release[patch,true]      # Dry run
    VERBOSE=1 rake release[patch] # Verbose output
DESC
task :release, %i[version dry_run] do |_t, args|
  def log(message, force: false)
    puts message if ENV['VERBOSE'] == '1' || force
  end

  def sh_with_retry(command, max_retries: 3)
    retries = 0
    max_retries = ENV.fetch('GEM_RELEASE_MAX_RETRIES', max_retries).to_i

    loop do
      log "Running: #{command}"
      success = system(command)
      return true if success

      retries += 1
      if retries >= max_retries
        raise "Command failed after #{max_retries} attempts: #{command}"
      end

      puts "Command failed (attempt #{retries}/#{max_retries}). Retrying..."
      if command.include?('gem push') || command.include?('gem release')
        puts 'If this was an OTP issue, enter new RubyGems OTP:'
      end
    end
  end

  # Check for uncommitted changes
  unless `git status --porcelain`.strip.empty?
    raise 'ERROR: Uncommitted changes found. Commit or stash them first.'
  end

  args_hash = args.to_hash
  version = args_hash.fetch(:version, 'patch')
  dry_run = args_hash[:dry_run]&.to_s&.downcase == 'true'

  gem_root = File.expand_path('..', __dir__)

  log "Starting release process for version: #{version}", force: true
  log "Dry run: #{dry_run}", force: true if dry_run

  # Pull latest changes
  log 'Pulling latest changes...', force: true
  sh_with_retry('git pull --rebase')

  # Bump version using gem-release
  log 'Bumping gem version...', force: true
  sh_with_retry("gem bump --version #{version} --no-commit")

  # Get the new version by loading the updated version file
  load File.join(gem_root, 'lib', 'uber_task', 'version.rb')
  new_version = UberTask::VERSION

  log "New version: #{new_version}", force: true

  # Update Gemfile.lock
  log 'Updating Gemfile.lock...', force: true
  sh_with_retry('bundle install')

  # Commit and tag
  log 'Committing version bump...', force: true
  unless dry_run
    sh_with_retry("git add -A && git commit -m 'Release v#{new_version}'")
    sh_with_retry("git tag -a v#{new_version} -m 'Version #{new_version}'")
  end

  # Push to git
  log 'Pushing to git...', force: true
  unless dry_run
    sh_with_retry('git push')
    sh_with_retry('git push --tags')
  end

  # Release the gem
  log 'Releasing gem to RubyGems...', force: true
  puts '=' * 80
  puts 'Enter your RubyGems OTP when prompted:'
  puts '=' * 80

  unless dry_run
    otp_option = ENV['RUBYGEMS_OTP'] ? "--otp #{ENV['RUBYGEMS_OTP']}" : ''
    sh_with_retry("gem release #{otp_option}")
  end

  log '=' * 80, force: true
  log "Successfully released uber_task v#{new_version}!", force: true
  log '=' * 80, force: true
  log '', force: true
  log 'Next steps:', force: true
  github_url = 'https://github.com/shakacode/uber_task/releases/new'
  log "  1. Create a GitHub release at #{github_url}", force: true
end
