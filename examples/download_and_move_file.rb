# frozen_string_literal: true

require 'uber_task'
require 'colorize'
require 'tmpdir'

require_relative 'download_file'
require_relative 'move_file'
require_relative 'failing_task'

EXISTENT_FILE_URI = 'https://github.com/shakacode/uber_task/raw/main/README.md'
NON_EXESTENT_FILE_URI = 'https://github.com/shakacode/uber_task/raw/main/NON_EXISTENT.md'
NON_VITAL_FILE_URI = 'https://github.com/shakacode/uber_task/raw/main/NON_VITAL.md'

module Examples
  class DownloadAndMoveFile
    def self.run(uri:, download_path:, move_path:)
      UberTask.run('Download and move file') do
        UberTask.on_success do
          UberTask.logger.info(
            'Top-level task was completed successfully!'.green,
          )
        end

        UberTask.on_subtask_error do |_task, event, err|
          case err
          # Network errors occuring in subtasks are handled here in top-level
          when OpenURI::HTTPError
            UberTask.retry(reason: err, wait: 5)
          # Subtasks can be skipped
          when Examples::FailingTask::Error
            UberTask.logger.info(
              'Encountered expected error, skipping...'.yellow,
            )

            UberTask.skip
          else
            UberTask.logger.error(
              "Encountered unexpected error - #{err.message}".red,
            )
            event.handled
          end
        end

        Examples::DownloadFile.run(
          uri: NON_VITAL_FILE_URI,
          to: download_path,
          retry_count: 1,
          vital: false, # execution won't stop when this task fails
        )

        Examples::FailingTask.run

        Examples::DownloadFile.run(
          uri: uri,
          to: download_path,
          retry_count: 3,
          vital: true, # execution will stop if this task fails
        )

        Examples::MoveFile.run(from: download_path, to: move_path)
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Dir.mktmpdir do |dir|
    download_path = File.join(dir, 'download_path')
    move_path = File.join(dir, 'move_path')

    puts '--- Running successfull case ---'
    Examples::DownloadAndMoveFile.run(
      uri: EXISTENT_FILE_URI,
      download_path: download_path,
      move_path: move_path,
    )

    puts "\n--- Running case which fails to download file ---\n"
    Examples::DownloadAndMoveFile.run(
      uri: NON_EXESTENT_FILE_URI,
      download_path: download_path,
      move_path: move_path,
    )
  end
end
