# frozen_string_literal: true

describe UberTask do
  describe '.on_report' do
    context 'when no block is passed' do
      it 'returns nil' do
        described_class.run do |task|
          expect(described_class.on_report).to be_nil
        end
      end
    end

    context 'when a block is passed' do
      it 'returns nil' do
        described_class.run do |task|
          result = described_class.on_report do
            "Added some logs"
          end

          expect(result.call).to eq("Added some logs")
        end
      end
    end
  end
  
  describe '.on_retry' do
    context 'when no block is passed' do
      it 'returns the wait time and set handlers retry to nil' do
        described_class.run do |task|
          described_class.on_retry(report: false, wait: 12)

          expect(task.handlers[:retry]).to be_nil
          expect(task.retry_info.report).to be false
          expect(task.retry_info.wait).to eq(12)
        end
      end
    end

    context 'when a block is passed' do
      it 'returns the wait time and set handlers retry to the passed block' do
        expected_block = {
          first_name: "Sam",
          last_name: "Example"
        }

        described_class.run do |task|
          described_class.on_retry(report: true, wait: 30) do
            expected_block
          end

          expect(task.handlers[:retry].call).to eq(expected_block)
          expect(task.retry_info.report).to be true
          expect(task.retry_info.wait).to eq(30)
        end
      end
    end
  end
end
