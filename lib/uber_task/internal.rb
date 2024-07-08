# frozen_string_literal: true

module UberTask
  module Internal
    def self.trace
      return unless Thread.current[:__uber_task_trace__]

      UberTask.logger.debug yield
    end
  end
end
