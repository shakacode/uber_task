# frozen_string_literal: true

module UberTask
  module Internal
    def self.trace
      if Thread.current[:__uber_task_trace__]
        message = yield
        puts message
      end
    end
  end
end
