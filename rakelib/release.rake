# frozen_string_literal: true

require_relative 'release/workflow'

Rake::Task[:release].clear if Rake::Task.task_defined?(:release)

desc 'Prepare or publish: release[version,dry_run,override_version_policy]'
task :release, %i[version dry_run override_version_policy] do |_task, args|
  UberTaskRelease::Workflow.new(root: File.expand_path('..', __dir__)).release(
    args[:version],
    dry_run: UberTaskRelease::Versions.flag(args[:dry_run]),
    override: UberTaskRelease::Versions.flag(args[:override_version_policy]),
  )
end

desc 'Synchronize committed GitHub notes: sync_github_release[version,dry_run]'
task :sync_github_release, %i[version dry_run] do |_task, args|
  UberTaskRelease::Workflow.new(root: File.expand_path('..', __dir__)).sync(
    args[:version],
    dry_run: UberTaskRelease::Versions.flag(args[:dry_run]),
  )
end
