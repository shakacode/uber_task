# frozen_string_literal: true

module UberTask
  # We are inheriting from Exception to make sure it won't be caught by accident
  # which would affect the flow the tasks.
  class RetryTask < Exception # rubocop:disable Lint/InheritException
    attr_accessor :reason,
                  :wait

    def initialize(reason: nil, wait: 0)
      validate_wait_value!(wait)

      super('Requested to retry the task.')
      @reason = reason
      @wait = wait
    end

    private

    def validate_wait_value!(value)
      raise ArgumentError, '`wait` is not numberic' unless value.is_a?(Numeric)
      raise ArgumentError, '`wait` cannot be negative' if value.negative?
    end
  end
end
