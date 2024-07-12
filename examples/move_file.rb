# frozen_string_literal: true

require 'uber_task'
require 'colorize'
require 'fileutils'

module Examples
  class MoveFile
    def self.run(from:, to:, **task_options)
      UberTask.run(
        'Move file',
        default_retry_wait: 1,
        retry_count: 3,
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
    end
    private_class_method :move_file!
  end
end
