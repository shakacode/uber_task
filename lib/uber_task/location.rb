# frozen_string_literal: true

module UberTask
  class Location
    attr_accessor :path,
                  :line

    def initialize(path:, line:)
      @path = Internal::Path.shorten(path)
      @line = line
    end

    def to_s
      "#{path}:#{line}"
    end
  end
end
