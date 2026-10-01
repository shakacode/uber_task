# frozen_string_literal: true

require 'bundler'
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'rubygems/package'
require 'tmpdir'
require_relative 'versions'
require_relative 'publication'

module UberTaskRelease
  class Workflow
    include Publication

    REPOSITORY = 'shakacode/uber_task'
    VERSION_FILE = 'lib/uber_task/version.rb'

    def initialize(root:, output: $stdout, input: $stdin)
      @root = File.realpath(root)
      @output = output
      @input = input
      @completed = []
      @otp = ENV.fetch('RUBYGEMS_OTP', nil)
    end

    def capture(*args, root: @root, env: {})
      Bundler.with_unbundled_env do
        environment = { 'BUNDLE_GEMFILE' => File.join(root,
                                                      'Gemfile') }.merge(env)
        out, err, status = Open3.capture3(environment, *args, chdir: root)
        [utf8(out), utf8(err), status]
      end
    rescue SystemCallError => err
      raise Error, "Cannot run #{args.first}: #{err.class}"
    end

    # Git, gh and the release files are UTF-8 whatever the caller's locale;
    # a C locale would tag their bytes US-ASCII and break string handling.
    def utf8(text)
      text.dup.force_encoding(Encoding::UTF_8).scrub
    end

    def read(root, path)
      text = File.read(File.join(root, path), encoding: Encoding::UTF_8)
      raise Error, "#{path} is not valid UTF-8" unless text.valid_encoding?
      text
    end

    def run(*args, root: @root, env: {})
      out, err, status = capture(*args, root: root, env: env)
      unless status.success?
        raise Error, redact("#{args.first} failed: #{out}\n#{err}")
      end
      out.strip
    end

    def redact(message)
      secrets = [@otp, ENV.fetch('RUBYGEMS_OTP', nil),
                 ENV.fetch('GEM_HOST_API_KEY', nil)]
      secrets.compact.reject(&:empty?).each do |secret|
        message = message.gsub(secret, '[REDACTED]')
      end
      message.strip
    end

    def git(*args, root: @root)
      run('git', *args, root: root)
    end

    def preflight
      raise Error, 'Commit or stash checkout changes first' unless git(
        'status', '--porcelain'
      ).empty?
      @remote = git('remote', 'get-url', 'origin')
      unless @remote.match?(%r{\A(?:https://github\.com/|git@github\.com:)shakacode/uber_task(?:\.git)?\z})
        raise Error, "origin must identify #{REPOSITORY} on github.com"
      end
      run('gh', 'auth', 'status', '--hostname', 'github.com')
      metadata = JSON.parse(run('gh', 'api', "repos/#{REPOSITORY}"))
      unless metadata['full_name'] == REPOSITORY && metadata.dig('permissions',
                                                                 'push')
        raise Error, "GitHub write access to #{REPOSITORY} is required"
      end
      run('bundle', 'check')
      run('bundle', 'exec', 'gem', 'bump', '--help')
      @branch = git('branch', '--show-current')
      @head = git('rev-parse', 'HEAD')
    rescue JSON::ParserError => err
      raise Error, "Invalid GitHub preflight response: #{err.class}"
    end

    # Independent refs and objects keep caller files/index/tags unchanged on
    # success and failure, unlike a worktree's shared refs.
    def isolated
      Dir.mktmpdir('uber-task-release-') do |directory|
        checkout = File.join(directory, 'checkout')
        git('clone', '--quiet', '--no-hardlinks', '--no-local', @root, checkout)
        git('remote', 'set-url', 'origin', @remote, root: checkout)
        git('for-each-ref', '--format=%(refname)', 'refs/tags',
            root: checkout).lines.each do |ref|
          git('update-ref', '-d', ref.strip, root: checkout)
        end
        git('fetch', '--quiet', '--tags', 'origin', @branch, root: checkout)
        lock = File.join(@root, 'Gemfile.lock')
        FileUtils.cp(lock, checkout) if File.file?(lock)
        yield checkout
      end
    end

    def release(requested = '', dry_run: false, override: false)
      preflight
      isolated do |root|
        version, prepared, changed = plan(root, requested, override)
        prepare_files(root, version, prepared) if changed
        artifact = build(root, version)
        finish(root, version, artifact, changed, dry_run)
      end
    rescue Error => err
      completed = @completed.empty? ? 'none' : @completed.join(', ')
      raise Error, "#{err.message}\nCompleted: #{completed}. " \
                   'Retry the same explicit version; ' \
                   'use sync_github_release for notes-only recovery.'
    end

    def plan(root, requested, override)
      current = Versions.current(read(root, VERSION_FILE))
      changelog = read(root, 'CHANGELOG.md')
      tags = git('tag', '-l', root: root).lines.map(&:strip)
      version = Versions.resolve(requested, current, changelog, tags: tags)
      if Gem::Version.new(version) < Gem::Version.new(current)
        raise Error, 'A release cannot downgrade the checkout version'
      end
      prepared = Versions.prepare(changelog, version)
      Versions.validate!(
        version, tags,
        Versions.section(prepared, version), override: override, output: @output
      )
      branch_allowed!(version)
      remote_head!(root)
      max_retries
      [version, prepared, version != current || prepared != changelog]
    end

    def prepare_files(root, version, changelog)
      git('switch', '-c', "prepare-release/v#{version}", root: root)
      run('bundle', 'exec', 'gem', 'bump', '--version', version,
          '--no-commit', root: root)
      actual = Versions.current(read(root, VERSION_FILE))
      unless actual == version
        raise Error, 'gem-release did not produce the requested version'
      end
      File.binwrite(File.join(root, 'CHANGELOG.md'), changelog)
      run('bundle', 'install', root: root)
    end

    def finish(root, version, artifact, changed, dry_run)
      if dry_run
        action = changed ? 'open a preparation PR' : 'publish after exact CI'
        @output.puts "DRY RUN: #{version} built in isolation; would #{action}"
      elsif changed
        prepare_pr(root, version)
      else
        publish(root, version, artifact)
      end
    end

    def branch_allowed!(version)
      prerelease = Gem::Version.new(version).prerelease?
      allowed = @branch == 'main' ||
                (prerelease && @branch.start_with?('release/'))
      return if allowed
      raise Error,
            'Use main for stable releases; main or release/* for prereleases'
    end

    def remote_head!(root)
      remote = git('ls-remote', '--heads', 'origin',
                   "refs/heads/#{@branch}", root: root).split.first
      return if remote == @head
      raise Error,
            "Update #{@branch} to its remote head and rerun"
    end

    def build(root, version)
      artifact = File.join(root, 'pkg', "uber_task-#{version}.gem")
      FileUtils.mkdir_p(File.dirname(artifact))
      epoch = git('show', '-s', '--format=%ct', 'HEAD', root: root)
      run('bundle', 'exec', 'gem', 'build', 'uber_task.gemspec',
          '--output', artifact,
          root: root, env: { 'SOURCE_DATE_EPOCH' => epoch })
      spec = Gem::Package.new(artifact).spec
      unless spec.name == 'uber_task' && spec.version.to_s == version
        raise Error, 'Built gem identity does not match requested release'
      end
      artifact
    end

    def prepare_pr(root, version)
      branch = "prepare-release/v#{version}"
      unless git('ls-remote', '--heads', 'origin', "refs/heads/#{branch}",
                 root: root).empty?
        raise Error,
              "#{branch} exists; inspect its PR instead of overwriting it"
      end
      files = [VERSION_FILE, 'CHANGELOG.md']
      files << 'Gemfile.lock' unless git('ls-files', 'Gemfile.lock',
                                         root: root).empty?
      run('bundle', 'exec', 'rake', root: root)
      git('add', '--', *files, root: root)
      git('commit', '-m', "Prepare UberTask #{version}", root: root)
      git('push', 'origin', "HEAD:refs/heads/#{branch}", root: root)
      @completed << "preparation branch #{branch} pushed"
      notes = File.join(root, 'release-pr.txt')
      File.write(notes, "Prepare UberTask #{version}. Merge into #{@branch}, " \
                        'update that checkout, then run bundle exec rake ' \
                        "\"release[#{version}]\". Publication requires " \
                        'passing RSpec and Rubocop at the exact commit.')
      url = run('gh', 'pr', 'create', '--repo', REPOSITORY,
                '--base', @branch, '--head', branch,
                '--title', "Prepare UberTask #{version}",
                '--body-file', notes, root: root)
      @output.puts "Preparation PR: #{url}. Nothing tagged or published."
    end
  end
end
