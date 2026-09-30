# frozen_string_literal: true

require 'net/http'
require 'io/console'
require 'tempfile'

module UberTaskRelease
  module Publication
    def ci_passed!(root)
      endpoint = "repos/#{Workflow::REPOSITORY}/commits/#{@head}/check-runs"
      pages = JSON.parse(run('gh', 'api', '--paginate', '--slurp',
                             endpoint, root: root))
      checks = pages.flat_map { |page| page.fetch('check_runs') }
      %w[RSpec Rubocop].each do |name|
        candidates = checks.select { |entry| release_check?(entry, name) }
        check = candidates.max_by { |entry| entry.fetch('id') }
        next if successful_check?(check)
        raise Error,
              "#{name} must pass for exact commit #{@head}; " \
              'no CI override is supported'
      end
    rescue JSON::ParserError, KeyError => err
      raise Error, "Cannot establish release CI: #{err.class}"
    end

    def successful_check?(check)
      check && check['status'] == 'completed' &&
        check['conclusion'] == 'success'
    end

    def release_check?(entry, name)
      entry['name'] == name && entry['head_sha'] == @head &&
        entry.dig('app', 'slug') == 'github-actions'
    end

    def remote_tag!(root, version)
      tag = "v#{version}"
      refs = git('ls-remote', 'origin', "refs/tags/#{tag}",
                 "refs/tags/#{tag}^{}", root: root)
             .lines.map(&:split).to_h do |sha, ref|
        [ref, sha]
      end
      sha = refs["refs/tags/#{tag}^{}"] || refs["refs/tags/#{tag}"]
      if sha && sha != @head
        raise Error,
              "Tag #{tag} points to another commit; never overwrite it"
      end
      sha
    end

    def publish(root, version, artifact)
      unless git('rev-parse', 'HEAD', root: root) == @head
        raise Error, 'Release checkout changed after preflight'
      end
      remote_head!(root)
      ci_passed!(root)
      remote_tag!(root, version)
      published?(version, artifact)
      tag = "v#{version}"
      if git('tag', '-l', tag, root: root).empty?
        git('tag', '-a', tag, @head, '-m', "UberTask #{version}", root: root)
      elsif git('rev-parse', "#{tag}^{commit}", root: root) != @head
        raise Error, "Local tag #{tag} conflicts; never overwrite it"
      end
      git('push', 'origin', "refs/tags/#{tag}", root: root)
      @completed << "tag #{tag} pushed at #{@head}"
      publish_gem(root, version, artifact)
      @completed << "RubyGems #{version} verified"
      sync_notes(root, version)
      @completed << "GitHub #{tag} notes synchronized"
      @output.puts "RELEASE COMPLETE: #{@completed.join(', ')}"
    end

    def rubygems_metadata(version)
      uri = URI("https://rubygems.org/api/v2/rubygems/uber_task/versions/#{version}.json")
      response = Net::HTTP.start(
        uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20
      ) { |http| http.get(uri.request_uri) }
      return nil if response.code == '404'
      unless response.code == '200'
        raise Error,
              "RubyGems lookup failed (HTTP #{response.code})"
      end
      JSON.parse(response.body)
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError => err
      raise Error, "Cannot establish RubyGems publication state: #{err.class}"
    end

    def published?(version, artifact)
      metadata = rubygems_metadata(version)
      return false unless metadata
      if metadata['yanked']
        raise Error, "RubyGems #{version} is yanked; do not republish it"
      end
      unless metadata['sha'] == Digest::SHA256.file(artifact).hexdigest
        raise Error,
              "RubyGems #{version} has a different or unverifiable artifact; " \
              'stop and inspect'
      end
      @output.puts "Verified RubyGems #{version}; skipping duplicate upload"
      true
    end

    def max_retries
      count = Integer(ENV.fetch('GEM_RELEASE_MAX_RETRIES', '3'))
      unless (1..3).cover?(count)
        raise Error,
              'GEM_RELEASE_MAX_RETRIES must be 1..3'
      end
      count
    rescue ArgumentError
      raise Error, 'GEM_RELEASE_MAX_RETRIES must be 1..3'
    end

    def otp!(fresh: false)
      @otp = nil if fresh
      unless @otp
        @output.print 'RubyGems OTP: '
        @otp = read_otp
      end
      unless @otp&.match?(/\A\d{6,8}\z/)
        raise Error,
              'Provide a valid RubyGems OTP; no OTP value is logged'
      end
      @otp
    end

    def read_otp
      if @input.respond_to?(:noecho) && @input.tty?
        @input.noecho(&:gets)&.strip
      else
        @input.gets&.strip
      end
    end

    def publish_gem(root, version, artifact)
      return if published?(version, artifact)
      max_retries.times do |attempt|
        otp!(fresh: attempt.positive?)
        out, err, status = capture('gem', 'push', artifact, '--host', 'https://rubygems.org',
                                   '--otp', @otp, root: root)
        return true if published?(version, artifact)
        recoverable = recoverable_failure?("#{out}\n#{err}")
        unless !status.success? && recoverable && attempt + 1 < max_retries
          raise Error,
                'Gem publication did not verify; output withheld to avoid ' \
                'credential disclosure'
        end
        @output.puts 'Recoverable publication failure; supply a fresh OTP'
      end
    end

    def recoverable_failure?(message)
      pattern = /OTP|one.time.password|MFA|timed? out|50[23]|connection reset/i
      message.match?(pattern)
    end

    def sync(version, dry_run: false)
      version = Versions.normalize(version.to_s)
      preflight
      isolated { |root| sync_notes(root, version, dry_run: dry_run) }
    end

    def sync_notes(root, version, dry_run: false)
      tag = "v#{version}"
      tagged = tagged_commit!(root, tag)
      actual = Versions.current(git('show', "#{tag}:#{Workflow::VERSION_FILE}",
                                    root: root))
      unless actual == version
        raise Error,
              "Tag #{tag} contains version #{actual}"
      end
      notes = Versions.section(git('show', "#{tag}:CHANGELOG.md", root: root),
                               version)
      unless Versions.substantive?(notes)
        raise Error,
              "Tag #{tag} has missing or empty changelog notes"
      end
      publish_notes(root, version, notes, tagged, dry_run)
    end

    def tagged_commit!(root, tag)
      refs = git('ls-remote', 'origin', "refs/tags/#{tag}",
                 "refs/tags/#{tag}^{}", root: root)
      raise Error, "Remote tag #{tag} is missing" if refs.empty?
      tagged = git('rev-parse', "#{tag}^{commit}", root: root)
      remote = refs.lines.map(&:split).to_h { |sha, ref| [ref, sha] }
      remote_commit = remote["refs/tags/#{tag}^{}"] ||
                      remote["refs/tags/#{tag}"]
      unless remote_commit == tagged
        raise Error,
              "Local and remote tag #{tag} differ"
      end
      tagged
    end

    def publish_notes(root, version, notes, tagged, dry_run)
      tag = "v#{version}"
      if dry_run
        @output.puts "DRY RUN: synchronize #{tag} from committed #{tagged}"
        return
      end
      endpoint = "repos/#{Workflow::REPOSITORY}/releases/tags/#{tag}"
      out, err, status = capture('gh', 'api', endpoint, root: root)
      unless status.success? || "#{out}\n#{err}".include?('HTTP 404')
        raise Error,
              'Cannot establish GitHub release state; ' \
              'retry notes synchronization'
      end
      Tempfile.create(['uber-task-notes-', '.md']) do |file|
        file.write(notes)
        file.flush
        args = ['gh', 'release', status.success? ? 'edit' : 'create', tag,
                '--repo', Workflow::REPOSITORY,
                '--title', "UberTask #{version}",
                '--notes-file', file.path]
        if status.success?
          args << "--prerelease=#{Gem::Version.new(version).prerelease?}"
        else
          args << '--verify-tag'
          args << '--prerelease' if Gem::Version.new(version).prerelease?
        end
        run(*args, root: root)
      end
    end
  end
end
