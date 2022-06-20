# frozen_string_literal: true

module UberTask
  # We are inheriting from Exception to make sure it won't be caught by accident
  # which would affect the flow the tasks.
  class EventHandled < Exception; end # rubocop:disable Lint/InheritException
end
