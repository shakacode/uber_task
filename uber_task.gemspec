# frozen_string_literal: true

require 'rake'
require_relative 'lib/uber_task'

Gem::Specification.new do |s|
  s.name = 'uber_task'
  s.version = UberTask::VERSION
  s.authors = [
    'Alexandre Borela',
    'Justin Gordon',
  ]
  s.email = [
    'alexandre@shakacode.com',
    'justin@shakacode.com',
  ]
  s.summary = 'Sequential task management'
  s.description = <<~DESC.strip
    Run tasks in a structured way with support for retry and progress report.
  DESC
  s.homepage = 'https://github.com/shakacode/uber_task'
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.7.5'
  s.metadata['homepage_uri'] = s.homepage
  s.metadata['source_code_uri'] = 'https://github.com/shakacode/uber_task'
  s.metadata['changelog_uri'] = <<~LINK.strip
    https://github.com/shakacode/uber_task/blob/main/CHANGELOG.md
  LINK
  s.metadata['rubygems_mfa_required'] = 'true'

  s.require_paths = ['lib']
  s.files = FileList.new(['lib/**/*.rb']).to_a
end
