# frozen_string_literal: true

module UberTask
  # We are inheriting from Exception to make sure it won't be caught by accident
  # which would affect the flow the tasks.
  class SkipTask < Exception # rubocop:disable Lint/InheritException
    attr_accessor :reason

    def initialize(reason: nil)
      super('Requested to skip the task.')
      @reason = reason
    end
  end
end
