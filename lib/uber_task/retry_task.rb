# frozen_string_literal: true

module UberTask
  # We are inheriting from Exception to make sure it won't be caught by accident
  # which would affect the flow the tasks.
  class RetryTask < Exception # rubocop:disable Lint/InheritException
    attr_accessor :reason,
                  :wait

    def initialize(reason: nil, wait: nil)
      super('Requested to retry the task.')
      @reason = reason
      @wait = wait
    end
  end
end
