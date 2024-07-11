# frozen_string_literal: true

require 'uber_task'
require 'colorize'

require_relative 'download_file'
require_relative 'move_file'

module Examples
  class DownloadAndMoveFile
    def self.run(source:, download_path:, move_path:)
      UberTask.run('Download and move file', retry_count: 2) do
        UberTask.on_success do
          UberTask.logger.info(
            'Top-level task was completed successfully!'.green,
          )
        end

        UberTask.on_subtask_error do
          UberTask.logger.info(
            'Unexpected subtask error can be caught on top-level task ' \
            'and an early return can be made, ' \
            'isn\'t that cool!?'.underline,
          )
          return # Try to remove this line and see what happens!
        end

        # Notice that we are passing `vital: true` option so that
        # an early return can be made if task fails
        begin
          Examples::DownloadFile.run(
            source: source,
            to: download_path,
            vital: true,
          )
        rescue StandardError => err
          UberTask.logger.info "Failed to download file -- #{err.message}"
          return
        end

        Examples::MoveFile.run(from: download_path, to: move_path)
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Dir.mktmpdir do |dir|
    download_path = File.join(dir, 'test')
    move_path = File.join(dir, 'new_path')

    puts '--- Running successfull case ---'
    Examples::DownloadAndMoveFile.run(
      source: VALID_FILE_URI,
      download_path: download_path,
      move_path: move_path,
    )

    puts "\n--- Running case which fails to download file ---\n"
    Examples::DownloadAndMoveFile.run(
      source: NON_EXESTENT_FILE_URI,
      download_path: download_path,
      move_path: move_path,
    )

    puts "\n--- Running case with invalid download path ---\n"
    Examples::DownloadAndMoveFile.run(
      source: VALID_FILE_URI,
      download_path: '/invalid_path',
      move_path: move_path,
    )

    puts "\n--- Running case with invalid move path ---\n"
    Examples::DownloadAndMoveFile.run(
      source: VALID_FILE_URI,
      download_path: download_path,
      move_path: '/invalid_path',
    )
  end
end
