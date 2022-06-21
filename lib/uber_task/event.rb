# frozen_string_literal: true

module UberTask
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
