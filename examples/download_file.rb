# frozen_string_literal: true

require 'uber_task'
require 'colorize'
require 'open-uri'

module Examples
  class DownloadFile
    def self.run(uri:, to:, **task_options)
      UberTask.run(
        'Download file from external source',
        default_retry_wait: 5,
        retry_count: 3,
        **task_options,
      ) do
        UberTask.on_success do
          UberTask.logger.info(
            "Downloaded file #{uri} and saved it at #{to}".green,
          )
        end

        UberTask.on_retry do
          UberTask.logger.info(
            "Retrying to download file from #{uri}...".yellow,
          )
        end

        save_external_file!(uri: uri, to: to)
      end
    end

    def self.save_external_file!(uri:, to:)
      URI.parse(uri).open { |io| File.write(to, io.read) }
    end
    private_class_method :save_external_file!
  end
end
