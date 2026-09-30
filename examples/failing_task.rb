# frozen_string_literal: true

require 'uber_task'

module Examples
  class FailingTask
    class Error < StandardError
    end

    def self.run(**task_options)
      UberTask.run('Failing task', **task_options) do
        raise Error, 'failed'
      end
    end
  end
end
