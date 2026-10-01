# frozen_string_literal: true

require 'date'
require 'rubygems/version'

module UberTaskRelease
  class Error < StandardError; end

  # Adapted from control-plane-flow's changelog-first resolver for UberTask's
  # headings and RubyGems versions. Only changelog bump policy is overridable.
  module Versions
    module_function

    def flag(value)
      case value.to_s.strip.downcase
      when '', 'false' then false
      when 'true' then true
      else raise Error, 'Flags must be true or false'
      end
    end

    def normalize(value)
      valid = value.match?(/\A\d[0-9A-Za-z.-]*\z/) &&
              Gem::Version.correct?(value)
      raise Error, "Invalid version: #{value.inspect}" unless valid
      Gem::Version.new(value).to_s
    end

    def current(text)
      match = text.match(/VERSION\s*=\s*['"]([^'"]+)['"]/) or
        raise Error, 'Cannot read lib/uber_task/version.rb'
      normalize(match[1])
    end

    def section(changelog, version)
      pattern = /^### \[([^\]]+)\][^\n]*\n(.*?)(?=^### \[|\z)/m
      changelog.scan(pattern).each do |heading, notes|
        next unless same_section?(heading, version)
        return notes.gsub(/^Changes since the last non-beta release\.\n?/, '')
                    .strip
      end
      nil
    end

    def same_section?(heading, version)
      return heading == version if [heading, version].include?('Unreleased')
      normalize(heading) == normalize(version)
    rescue Error
      false
    end

    def substantive?(notes)
      notes && !notes.gsub(/^#+[^\n]*|_Nothing yet\._/, '').strip.empty?
    end

    def default_input(current, changelog, tags)
      prepared = changelog.scan(/^### \[([^\]]+)\]/).flatten
                          .find { |value| value != 'Unreleased' }
      return 'patch' unless prepared
      version = normalize(prepared)
      return version if Gem::Version.new(version) > Gem::Version.new(current)
      if tags.include?("v#{current}") &&
         substantive?(section(changelog, 'Unreleased'))
        return 'patch'
      end
      Gem::Version.new(version) >= Gem::Version.new(current) ? version : 'patch'
    end

    def resolve(requested, current, changelog, tags: [])
      input = requested.to_s.strip
      input = default_input(current, changelog, tags) if input.empty?
      return normalize(input) unless %w[patch minor major].include?(input)
      bump(input, current)
    end

    def bump(input, current)
      if input == 'patch' && Gem::Version.new(current).prerelease?
        raise Error,
              'Patch cannot promote a prerelease; use an explicit version'
      end
      parts = Gem::Version.new(current).release.segments
      parts << 0 while parts.length < 3
      index = %w[major minor patch].index(input)
      parts[index] += 1
      ((index + 1)...3).each { |position| parts[position] = 0 }
      parts.first(3).join('.')
    end

    def prepare(changelog, version, date: Date.today)
      notes = section(changelog, version)
      return changelog if substantive?(notes)
      raise Error, "Changelog section #{version} is empty" if notes
      notes = section(changelog, 'Unreleased')
      unless substantive?(notes)
        raise Error, "Add meaningful Unreleased or #{version} notes"
      end
      pattern = /^### \[Unreleased\][^\n]*\n.*?(?=^### \[|\z)/m
      changelog.sub(pattern) do
        "### [Unreleased]\n\n_Nothing yet._\n\n" \
          "### [#{version}] - #{date.iso8601}\n\n#{notes}\n\n"
      end
    end

    def validate!(version, tags, notes, override:, output:)
      target = Gem::Version.new(version)
      versions = tags.grep(/\Av\d/).map do |tag|
        Gem::Version.new(normalize(tag[1..]))
      end
      latest = versions.max
      if latest && target < latest
        raise Error, "Version #{version} is older than latest tag #{latest}"
      end
      stable = versions.reject(&:prerelease?).max
      return unless bump_policy_applies?(stable, target)
      validate_bump!(stable, target, notes, override: override, output: output)
    end

    def bump_policy_applies?(stable, target)
      stable && target > stable && !target.prerelease?
    end

    def expected_bump(notes)
      case notes
      when /^#### Breaking\b/i then :major
      when /^#### (Added|Features?)\b/i then :minor
      when /^#### (Fixed|Security|Changed|Removed|Deprecated)\b/i then :patch
      end
    end

    def actual_bump(stable, target)
      index = (0..2).find do |position|
        target.segments.fetch(position, 0) != stable.segments.fetch(position, 0)
      end
      %i[major minor patch][index || 2]
    end

    def validate_bump!(stable, target, notes, override:, output:)
      expected = expected_bump(notes)
      actual = actual_bump(stable, target)
      return unless expected && expected != actual
      message = "Changelog implies #{expected}; " \
                "#{stable} -> #{target} is #{actual}"
      raise Error, message unless override
      output.puts "VERSION POLICY OVERRIDE: #{message}"
    end
  end
end
