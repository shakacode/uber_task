# frozen_string_literal: true

module UberTask
  class Location
    attr_accessor :path,
                  :line

    def initialize(path:, line:)
      @path = shorten(path)
      @line = line
    end

    def to_s
      "#{path}:#{line}"
    end

    private

    def shorten(path)
      rails_root = Rails&.root&.to_s
      if rails_root && path.start_with?(rails_root)
        path = path.delete_prefix(rails_root)
        "[PROJECT]#{path}"
      else
        path.gsub(%r{^.+?/(ruby)?gems}, '[GEM]')
      end
    end
  end
end
