# frozen_string_literal: true

require 'uber_task'
require 'colorize'
require 'open-uri'
require 'tmpdir'

VALID_FILE_URI = 'https://github.com/shakacode/uber_task/raw/main/README.md'
NON_EXESTENT_FILE_URI = 'https://github.com/shakacode/uber_task/raw/main/NON_EXISTENT.md'

module Examples
  class DownloadFile
    def self.run(to:, source: VALID_FILE_URI, **task_options)
      UberTask.run(
        'Download file from external source',
        default_retry_wait: 3,
        retry_count: 5,
        vital: false,
        **task_options,
      ) do
        UberTask.on_retry do
          UberTask.logger.info(
            "Retrying to download file from #{source}...".yellow,
          )
        end

        UberTask.on_success do
          UberTask.logger.info(
            "Downloaded file #{source} and saved it at #{to}".green,
          )
        end

        save_external_file!(source: source, to: to)
      end
    end

    def self.save_external_file!(source:, to:)
      URI.parse(source).open { |io| File.write(to, io.read) }
    rescue OpenURI::HTTPError => err
      raise UberTask::RetryTask.new(reason: err.message)
    end
    private_class_method :save_external_file!
  end
end

if __FILE__ == $PROGRAM_NAME
  Dir.mktmpdir do |dir|
    filepath = File.join(dir, 'test')

    puts '--- Running successfull case ---'
    Examples::DownloadFile.run(source: VALID_FILE_URI, to: filepath)

    puts "\n--- Running failing case with `vital: true`---\n"
    begin
      Examples::DownloadFile.run(
        source: NON_EXESTENT_FILE_URI,
        to: filepath,
        vital: true,
      )
    rescue StandardError
      UberTask.logger.info 'Error was raised'.red
    end

    puts "\n--- Running failing case with `vital: false`---\n"
    Examples::DownloadFile.run(
      source: NON_EXESTENT_FILE_URI,
      to: filepath,
      vital: false,
    )
    UberTask.logger.info 'Error wasn\'t raised'.green

    puts "\n--- Running failing case with `retry_count: 1`---\n"
    Examples::DownloadFile.run(
      source: NON_EXESTENT_FILE_URI,
      to: filepath,
      retry_count: 1,
    )

    puts "\n--- Running failing case with `default_retry_wait: 0`---\n"
    Examples::DownloadFile.run(
      source: NON_EXESTENT_FILE_URI,
      to: filepath,
      default_retry_wait: 0,
    )
  end
end
