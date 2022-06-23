# frozen_string_literal: true

module UberTask
  module Internal
    module Path
      def self.shorten(path)
        if defined?(Rails)
          rails_root = Rails.root.to_s
          if rails_root && path.start_with?(rails_root)
            path = path.delete_prefix(rails_root)
            return "[PROJECT]#{path}"
          end
        end
        path.gsub(%r{^.+?/(ruby)?gems}, '[GEM]')
      end
    end
  end
end
