# frozen_string_literal: true

require 'tmpdir'
require 'stringio'
require_relative '../../rakelib/release/workflow'

RSpec.describe UberTaskRelease::Workflow do
  let(:output) { StringIO.new }
  let(:workflow) { described_class.new(root: Dir.pwd, output: output) }
  let(:head) { 'a' * 40 }
  let(:success) { instance_double(Process::Status, success?: true) }
  let(:failure) { instance_double(Process::Status, success?: false) }

  before { workflow.instance_variable_set(:@head, head) }

  [SocketError, OpenSSL::SSL::SSLError].each do |network_error|
    it "reports completed steps after #{network_error} during verification" do
      allow(workflow).to receive(:preflight)
      allow(workflow).to receive(:isolated).and_yield(Dir.pwd)
      allow(workflow).to receive(:plan).and_return(['1.0.0', '', false])
      allow(workflow).to receive(:build).and_return('artifact.gem')
      allow(workflow).to receive(:finish) do
        workflow.instance_variable_get(:@completed) << 'tag v1.0.0 pushed'
        workflow.rubygems_metadata('1.0.0')
      end
      allow(Net::HTTP).to receive(:start).and_raise(network_error)
      expect { workflow.release('1.0.0') }
        .to raise_error(UberTaskRelease::Error,
                        /Cannot establish.*Completed: tag v1.0.0 pushed/m)
    end
  end

  describe 'preflight' do
    it 'refuses dirty callers before checking remote services' do
      allow(workflow).to receive(:git).with('status', '--porcelain')
                                      .and_return(' M README.md')
      expect(workflow).not_to receive(:run)
      expect { workflow.preflight }
        .to raise_error(UberTaskRelease::Error, /Commit or stash/)
    end

    it 'refuses an unexpected repository before checking remote services' do
      allow(workflow).to receive(:git).with('status', '--porcelain')
                                      .and_return('')
      allow(workflow).to receive(:git).with('remote', 'get-url', 'origin')
                                      .and_return('https://github.com/other/repo')
      expect(workflow).not_to receive(:run)
      expect { workflow.preflight }
        .to raise_error(UberTaskRelease::Error, /origin must identify/)
    end
  end

  def checks(conclusion: 'success', sha: head, app: 'github-actions')
    %w[RSpec Rubocop].map.with_index do |name, index|
      { 'name' => name, 'head_sha' => sha, 'app' => { 'slug' => app },
        'status' => 'completed', 'conclusion' => conclusion, 'id' => index }
    end
  end

  describe 'exact-commit CI' do
    def ci_response(entries)
      allow(workflow).to receive(:run).with(
        'gh', 'api', '--paginate', '--slurp',
        "repos/shakacode/uber_task/commits/#{head}/check-runs", root: Dir.pwd
      ).and_return(JSON.generate([{ 'check_runs' => entries }]))
    end

    it 'requires both official workflow checks' do
      ci_response(checks)
      expect { workflow.ci_passed!(Dir.pwd) }.not_to raise_error
    end

    [nil, 'failure', 'cancelled', 'skipped', 'neutral'].each do |conclusion|
      it "blocks #{conclusion.inspect} conclusions" do
        ci_response(checks(conclusion: conclusion))
        expect { workflow.ci_passed!(Dir.pwd) }
          .to raise_error(UberTaskRelease::Error, /must pass/)
      end
    end

    it 'blocks missing checks' do
      ci_response([])
      expect { workflow.ci_passed!(Dir.pwd) }
        .to raise_error(UberTaskRelease::Error, /RSpec must pass/)
    end

    it 'rejects stale commits and check-name impersonation' do
      [checks(sha: 'b' * 40), checks(app: 'other-app')].each do |entries|
        ci_response(entries)
        expect { workflow.ci_passed!(Dir.pwd) }
          .to raise_error(UberTaskRelease::Error, /must pass/)
      end
    end

    it 'uses the latest attempt rather than an older green check' do
      entries = checks + [checks(conclusion: 'failure').first.merge('id' => 10)]
      ci_response(entries)
      expect { workflow.ci_passed!(Dir.pwd) }
        .to raise_error(UberTaskRelease::Error, /must pass/)
    end
  end

  describe 'branch and tag gates' do
    it 'allows stable releases only from main' do
      workflow.instance_variable_set(:@branch, 'release/1.x')
      expect { workflow.branch_allowed!('1.0.0') }
        .to raise_error(UberTaskRelease::Error, /main/)
      expect { workflow.branch_allowed!('1.0.0.rc.1') }.not_to raise_error
      workflow.instance_variable_set(:@branch, 'prepare-release/v1.0.0.rc.1')
      expect { workflow.branch_allowed!('1.0.0.rc.1') }
        .to raise_error(UberTaskRelease::Error, /main/)
    end

    it 'checks the live branch rather than cached origin refs' do
      workflow.instance_variable_set(:@branch, 'main')
      allow(workflow).to receive(:git).with(
        'ls-remote', '--heads', 'origin', 'refs/heads/main', root: Dir.pwd
      ).and_return("#{'b' * 40}\trefs/heads/main")
      expect { workflow.remote_head!(Dir.pwd) }
        .to raise_error(UberTaskRelease::Error, /Update main/)
    end

    it 'refuses conflicting remote annotated tags' do
      allow(workflow).to receive(:git).and_return(
        "#{head}\trefs/tags/v1.0.0\n#{'b' * 40}\trefs/tags/v1.0.0^{}\n",
      )
      expect { workflow.remote_tag!(Dir.pwd, '1.0.0') }
        .to raise_error(UberTaskRelease::Error, /never overwrite/)
    end

    it 'never mutates a tag before CI succeeds' do
      allow(workflow).to receive(:git).with('rev-parse', 'HEAD', root: Dir.pwd)
                                      .and_return(head)
      allow(workflow).to receive(:remote_head!)
      allow(workflow).to receive(:ci_passed!).and_raise(UberTaskRelease::Error,
                                                        'pending')
      expect(workflow).not_to receive(:publish_gem)
      expect { workflow.publish(Dir.pwd, '1.0.0', 'unused') }
        .to raise_error(UberTaskRelease::Error, /pending/)
    end
  end

  describe 'RubyGems retries and recovery' do
    around do |example|
      previous = ENV.delete('RUBYGEMS_OTP')
      example.run
    ensure
      ENV['RUBYGEMS_OTP'] = previous if previous
    end

    it 'skips an existing version only when its artifact checksum matches' do
      Tempfile.create('gem') do |file|
        file.write('fixture artifact')
        file.flush
        sha = Digest::SHA256.file(file.path).hexdigest
        allow(workflow).to receive(:rubygems_metadata).and_return('sha' => sha)
        expect(workflow).not_to receive(:capture)
        expect { workflow.publish_gem(Dir.pwd, '1.0.0', file.path) }
          .not_to raise_error
        allow(workflow).to receive(:rubygems_metadata)
          .and_return('sha' => 'other')
        expect { workflow.publish_gem(Dir.pwd, '1.0.0', file.path) }
          .to raise_error(UberTaskRelease::Error, /different/)
      end
    end

    it 'keeps refreshed OTPs out of command arguments' do
      workflow.instance_variable_set(:@otp, '123456')
      workflow.instance_variable_set(:@input, StringIO.new("654321\n"))
      allow(workflow).to receive(:published?).and_return(false, false, true)
      expect(workflow).to receive(:capture).with(
        'gem', 'push', 'artifact.gem', '--host', 'https://rubygems.org',
        root: Dir.pwd, env: { 'GEM_HOST_OTP_CODE' => '123456' }
      ).ordered.and_return(['', 'Invalid OTP', failure])
      expect(workflow).to receive(:capture).with(
        'gem', 'push', 'artifact.gem', '--host', 'https://rubygems.org',
        root: Dir.pwd, env: { 'GEM_HOST_OTP_CODE' => '654321' }
      ).ordered.and_return(['ok', '', success])
      workflow.publish_gem(Dir.pwd, '1.0.0', 'artifact.gem')
      expect(output.string).not_to include('123456', '654321')
    end

    it 'does not retry unrelated errors or expose the command output' do
      workflow.instance_variable_set(:@otp, '123456')
      allow(workflow).to receive(:published?).and_return(false)
      expect(workflow).to receive(:capture).once.and_return(
        ['', 'API key denied: 123456', failure],
      )
      expect { workflow.publish_gem(Dir.pwd, '1.0.0', 'artifact.gem') }
        .to raise_error(UberTaskRelease::Error, /output withheld/)
    end

    it 'does not duplicate a push when a failed response actually published' do
      workflow.instance_variable_set(:@otp, '123456')
      allow(workflow).to receive(:published?).and_return(false, true)
      expect(workflow).to receive(:capture).once.and_return(['', 'timeout',
                                                             failure])
      expect { workflow.publish_gem(Dir.pwd, '1.0.0', 'artifact.gem') }
        .not_to raise_error
    end

    it 'rejects malformed OTP input without executing a command' do
      workflow.instance_variable_set(:@otp, '123456; bad')
      expect(workflow).not_to receive(:capture)
      expect { workflow.otp! }.to raise_error(UberTaskRelease::Error, /valid/)
    end

    it 'will not republish a yanked version' do
      allow(workflow).to receive(:rubygems_metadata)
        .and_return('yanked' => true)
      expect(workflow).not_to receive(:capture)
      expect { workflow.publish_gem(Dir.pwd, '1.0.0', 'unused') }
        .to raise_error(UberTaskRelease::Error, /yanked/)
    end

    it 'bounds repeated recoverable failures to three pushes' do
      workflow.instance_variable_set(:@otp, '123456')
      workflow.instance_variable_set(:@input, StringIO.new("654321\n234567\n"))
      allow(workflow).to receive(:published?).and_return(false)
      expect(workflow).to receive(:capture).exactly(3).times
                                           .and_return(['', 'Invalid OTP',
                                                        failure])
      expect { workflow.publish_gem(Dir.pwd, '1.0.0', 'unused') }
        .to raise_error(UberTaskRelease::Error, /output withheld/)
    end
  end

  describe 'GitHub notes-only recovery' do
    it 'reads notes and the version from the tag, not the working checkout' do
      allow(workflow).to receive(:tagged_commit!).and_return(head)
      expect(workflow).to receive(:git).with(
        'show', 'v1.0.0:lib/uber_task/version.rb', root: Dir.pwd
      ).and_return("VERSION = '1.0.0'")
      expect(workflow).to receive(:git).with(
        'show', 'v1.0.0:CHANGELOG.md', root: Dir.pwd
      ).and_return("### [1.0.0]\n\n- Committed notes.\n")
      expect(workflow).to receive(:publish_notes).with(
        Dir.pwd, '1.0.0', '- Committed notes.', head, false
      )
      workflow.sync_notes(Dir.pwd, '1.0.0')
    end

    it 'refuses a tag containing a different version' do
      allow(workflow).to receive(:tagged_commit!).and_return(head)
      allow(workflow).to receive(:git).and_return("VERSION = '0.9.0'")
      expect(workflow).not_to receive(:publish_notes)
      expect { workflow.sync_notes(Dir.pwd, '1.0.0') }
        .to raise_error(UberTaskRelease::Error, /contains version/)
    end

    it 'creates and then edits releases with explicit prerelease state' do
      allow(workflow).to receive(:capture).and_return(
        ['', 'HTTP 404', failure], ['{}', '', success]
      )
      commands = []
      allow(workflow).to receive(:run) do |*args, **_options|
        commands << args
        expect(File.read(args[args.index('--notes-file') + 1])).to eq('- Notes')
      end
      2.times do
        workflow.publish_notes(Dir.pwd, '1.0.0.rc.1', '- Notes', head, false)
      end
      expect(commands[0]).to include('create', '--verify-tag', '--prerelease')
      expect(commands[1]).to include('edit', '--prerelease=true')
      expect(commands.flatten).not_to include('gem', 'push')
    end

    it 'does not mistake authentication failure for a missing release' do
      allow(workflow).to receive(:capture).and_return(['', 'HTTP 403', failure])
      expect(workflow).not_to receive(:run)
      expect do
        workflow.publish_notes(Dir.pwd, '1.0.0', '- Notes', head, false)
      end.to raise_error(UberTaskRelease::Error, /Cannot establish/)
    end

    it 'performs no mutation or API write during notes dry run' do
      expect(workflow).not_to receive(:capture)
      expect(workflow).not_to receive(:run)
      workflow.publish_notes(Dir.pwd, '1.0.0', '- Notes', head, true)
    end
  end

  it 'reports the exact pushed tag when gem publication fails' do
    allow(workflow).to receive(:preflight)
    allow(workflow).to receive(:isolated).and_yield(Dir.pwd)
    allow(workflow).to receive(:plan).and_return(['1.0.0', '', false])
    allow(workflow).to receive(:build).and_return('artifact.gem')
    allow(workflow).to receive(:remote_head!)
    allow(workflow).to receive(:ci_passed!)
    allow(workflow).to receive(:remote_tag!)
    allow(workflow).to receive(:published?).and_return(false)
    allow(workflow).to receive(:git).with('rev-parse', 'HEAD', root: Dir.pwd)
                                    .and_return(head)
    allow(workflow).to receive(:git).with('tag', '-l', 'v1.0.0', root: Dir.pwd)
                                    .and_return('')
    expect(workflow).to receive(:git).with(
      'tag', '-a', 'v1.0.0', head, '-m', 'UberTask 1.0.0', root: Dir.pwd
    )
    expect(workflow).to receive(:git).with(
      'push', 'origin', 'refs/tags/v1.0.0', root: Dir.pwd
    )
    allow(workflow).to receive(:publish_gem)
      .and_raise(UberTaskRelease::Error, 'publication failed')
    expect(workflow).not_to receive(:sync_notes)
    expect { workflow.release('1.0.0') }
      .to raise_error(UberTaskRelease::Error, /Completed: tag v1.0.0 pushed at/)
  end
end
