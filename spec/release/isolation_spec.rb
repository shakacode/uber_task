# frozen_string_literal: true

require 'tmpdir'
require 'stringio'
require_relative '../../rakelib/release/workflow'

# External registries/GitHub are never called. Real Git clones, version bumps
# and gem builds exercise the isolation boundary; dependency installation is
# simulated so these integration tests are unattended and work offline.
class FixtureRelease < UberTaskRelease::Workflow
  attr_reader :commands
  attr_accessor :fail_build

  def initialize(**options)
    super
    @commands = []
  end

  def preflight
    raise UberTaskRelease::Error, 'dirty' unless git('status',
                                                     '--porcelain').empty?
    @remote = git('remote', 'get-url', 'origin')
    @branch = git('branch', '--show-current')
    @head = git('rev-parse', 'HEAD')
  end

  def run(*args, root: @root, env: {})
    @commands << args
    return fixture_bundle(args, root, env) if args.first == 'bundle'
    if args.first(3) == %w[gh pr create]
      return 'https://example.invalid/preparation-pr'
    end
    if args.first(2) == %w[git commit]
      args = ['git', '-c', 'user.name=Fixture', '-c',
              'user.email=fixture@example.invalid', *args.drop(1)]
    end
    super
  end

  def fixture_bundle(args, root, env)
    if args[1] == 'install'
      File.write(File.join(root, 'Gemfile.lock'), "isolated lockfile\n")
    elsif args.first(3) == %w[bundle exec gem]
      if fail_build && args[3] == 'build'
        raise UberTaskRelease::Error, 'fixture build failed'
      end
      plugin = File.join(Gem::Specification.find_by_name('gem-release')
                                          .full_gem_path,
                         'lib/rubygems_plugin.rb')
      environment = env.merge('GEM_HOME' => File.join(root, 'empty-gems'),
                              'GEM_PATH' => File.join(root, 'empty-gems'))
      run(Gem.ruby, '-r', plugin, '-rrubygems/gem_runner', '-e',
          'Gem::GemRunner.new.run(ARGV)', '--', *args.drop(3), root: root,
                                                               env: environment)
    end
    ''
  end
end

RSpec.describe 'Release isolation' do
  def git(root, *args)
    out, err, status = Open3.capture3('git', '-C', root, *args)
    raise err unless status.success?
    out.strip
  end

  def project(directory, note: 'Fix a demonstrated failure.')
    root = File.join(directory, 'caller')
    FileUtils.mkdir_p(File.join(root, 'lib/uber_task'))
    File.write(File.join(root, 'lib/uber_task/version.rb'),
               "module UberTask\n  VERSION = '0.1.0'\nend\n")
    File.write(File.join(root, 'uber_task.gemspec'), <<~GEMSPEC)
      require_relative 'lib/uber_task/version'
      Gem::Specification.new do |spec|
        spec.name = 'uber_task'
        spec.version = UberTask::VERSION
        spec.summary = 'Fixture'
        spec.authors = ['Fixture']
        spec.files = ['lib/uber_task/version.rb']
      end
    GEMSPEC
    File.write(File.join(root, 'CHANGELOG.md'), <<~NOTES)
      ### [Unreleased]

      #### Fixed

      - #{note}

      ### [0.1.0]

      - Initial release.
    NOTES
    File.write(File.join(root, '.gitignore'), "Gemfile.lock\npkg/\n")
    File.write(File.join(root, 'Gemfile.lock'), "caller lockfile\n")
    git(root, 'init', '-q', '-b', 'main')
    git(root, 'config', 'user.name', 'Fixture')
    git(root, 'config', 'user.email', 'fixture@example.invalid')
    git(root, 'add', '.')
    git(root, 'commit', '-qm', 'fixture')
    git(root, 'tag', 'v0.1.0')
    remote = File.join(directory, 'remote.git')
    git(root, 'clone', '-q', '--bare', root, remote)
    git(root, 'remote', 'add', 'origin', remote)
    [root, remote]
  end

  def snapshot(root, remote)
    files = %w[lib/uber_task/version.rb CHANGELOG.md Gemfile.lock .git/index]
            .map { |path| File.binread(File.join(root, path)) }
    [files, git(root, 'status', '--porcelain'),
     git(root, 'branch', '--show-current'),
     git(root, 'show-ref'), git(remote, 'show-ref')]
  end

  [false, true].each do |fail_build|
    outcome = fail_build ? 'failure' : 'success'
    it "preserves caller and remote state on #{outcome}" do
      Dir.mktmpdir do |directory|
        root, remote = project(directory)
        git(root, 'tag', 'v9.0.0')
        before = snapshot(root, remote)
        output = StringIO.new
        release = FixtureRelease.new(root: root, output: output)
        release.fail_build = fail_build
        if fail_build
          expect { release.release('patch', dry_run: true) }
            .to raise_error(UberTaskRelease::Error, /fixture build failed/)
        else
          release.release('', dry_run: true)
          expect(output.string).to include('0.1.1 built in isolation')
        end
        expect(snapshot(root, remote)).to eq(before)
        expect(release.commands).not_to include(
          a_collection_including('push'), a_collection_including('release')
        )
      end
    end
  end

  it 'pushes only a preparation branch with scoped release files' do
    Dir.mktmpdir do |directory|
      root, remote = project(directory)
      caller = snapshot(root, remote).first(4)
      release = FixtureRelease.new(root: root, output: StringIO.new)
      release.release('patch')
      expect(snapshot(root, remote).first(4)).to eq(caller)
      branch = 'refs/heads/prepare-release/v0.1.1'
      changed = git(remote, 'diff', '--name-only', 'main',
                    branch).lines.map(&:strip)
      expect(changed).to match_array(['CHANGELOG.md',
                                      'lib/uber_task/version.rb'])
      expect(git(remote, 'tag', '-l')).to eq('v0.1.0')
      pushes = release.commands.select { |args| args.first(2) == %w[git push] }
      expect(pushes).to eq([['git', 'push', 'origin', "HEAD:#{branch}"]])
    end
  end

  it 'prepares UTF-8 release notes under a non-UTF-8 locale' do
    note = 'Fix café — a demonstrated failure.'
    locale = Encoding.default_external
    Dir.mktmpdir do |directory|
      root, remote = project(directory, note: note)
      Encoding.default_external = Encoding::US_ASCII
      FixtureRelease.new(root: root, output: StringIO.new).release('patch')
      prepared, = Open3.capture2(
        'git', '-C', remote, 'show', 'prepare-release/v0.1.1:CHANGELOG.md',
        binmode: true
      )
      expect(prepared).to include("### [0.1.1]\n\n#### Fixed\n\n- #{note}".b)
    end
  ensure
    Encoding.default_external = locale
  end

  it 'reports a pushed preparation branch when PR creation fails' do
    Dir.mktmpdir do |directory|
      root, = project(directory)
      release = FixtureRelease.new(root: root, output: StringIO.new)
      allow(release).to receive(:run).and_call_original
      allow(release).to receive(:run).with(
        'gh', 'pr', 'create', any_args
      ).and_raise(UberTaskRelease::Error, 'GitHub unavailable')
      expect { release.release('patch') }
        .to raise_error(UberTaskRelease::Error, /preparation branch .* pushed/)
    end
  end
end
