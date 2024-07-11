# frozen_string_literal: true

require 'uber_task'
require 'colorize'
require 'tmpdir'
require 'fileutils'

module Examples
  class MoveFile
    def self.run(from:, to:, **task_options)
      UberTask.run(
        'Download file from external source',
        default_retry_wait: 1,
        retry_count: 3,
        vital: false,
        **task_options,
      ) do
        UberTask.on_success do
          UberTask.logger.info "Moved file from #{from} to #{to}".green
        end

        UberTask.on_retry do
          UberTask.logger.info(
            "Retrying to move file from #{from} to #{to}...".yellow,
          )
        end

        move_file!(from: from, to: to)
      end
    end

    def self.move_file!(from:, to:)
      FileUtils.mv(from, to)
    rescue Errno::ENOENT => err
      raise UberTask::RetryTask.new(reason: err.message)
    end
    private_class_method :move_file!
  end
end

if __FILE__ == $PROGRAM_NAME
  Dir.mktmpdir do |dir|
    File.open(File.join(dir, 'old_path'), 'w') do |file|
      file.write('test')

      puts '--- Running successfull case ---'
      Examples::MoveFile.run(from: file.path, to: File.join(dir, 'new_path'))
    end

    ### Notice that task has `vital: true` so error is raised
    puts "\n--- Running failing case with `vital: true`---\n"
    begin
      Examples::MoveFile.run(
        from: 'invalid_path',
        to: File.join(dir, 'new_path'),
        vital: true,
      )
    rescue StandardError
      UberTask.logger.info 'Error was raised'.red
    end

    ### Notice that task has `vital: false` so error isn't raised
    puts "\n--- Running failing case with `vital: false`---\n"
    Examples::MoveFile.run(
      from: 'invalid_path',
      to: File.join(dir, 'new_path'),
      vital: false,
    )

    puts "\n--- Running failing case with `retry_count: 1`---\n"
    Examples::MoveFile.run(
      from: 'invalid_path',
      to: File.join(dir, 'new_path'),
      retry_count: 1,
    )

    puts "\n--- Running failing case with `default_retry_wait: 3`---\n"
    Examples::MoveFile.run(
      from: 'invalid_path',
      to: File.join(dir, 'new_path'),
      default_retry_wait: 3,
    )
  end
end
