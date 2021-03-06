# frozen_string_literal: true

module UberTask
  class RetryInfo
    attr_accessor :report,
                  :retries_remaining,
                  :wait

    attr_reader :default_retries,
                :default_retry_wait,
                :retries

    def initialize(
      default_retries: nil,
      default_retry_wait: nil,
      retries: nil
    )
      @default_retries = default_retries || 0
      @default_retry_wait = default_retry_wait || 0
      @report = true
      @retries = retries || 0
      @retries_remaining = retries || 0
      @wait = 0
    end

    def message(wait: nil)
      if wait.nil?
        wait = @wait
      end

      if wait < 1
        wait = default_retry_wait || 0
      end

      if wait.positive?
        <<~MSG.strip
          Retrying in #{wait} seconds... (#{retries_remaining} retries remaining)
        MSG
      else
        <<~MSG.strip
          Retrying... (#{retries_remaining} retries remaining)
        MSG
      end
    end
  end
end
