# frozen_string_literal: true

describe UberTask do
  describe '.run' do
    it 'retries the task' do
      run_count = 0

      UberTask.run(retry_count: 3) do
        if run_count < 2
          run_count += 1
          UberTask.retry(wait: 1)
        end
      end

      expect(run_count).to be(2)
    end
  end
end
