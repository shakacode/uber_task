# frozen_string_literal: true

module UberTask
  # We are inheriting from Exception to make sure it won't be caught by accident
  # which would affect the flow the tasks.
  class Event
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def handled
      raise EventHandled
    end
  end
end
