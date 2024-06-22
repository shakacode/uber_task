# frozen_string_literal: true

describe UberTask do
  describe '.current' do
    context 'when there are no tasks being run' do
      it 'returns nil' do
        expect(described_class.current).to be_nil
      end
    end

    context 'when there is a task' do
      it 'returns the current task' do
        described_class.run do |task|
          expect(described_class.current).to eq(task)
        end

        described_class.run do |task1|
          described_class.run do |task2|
            described_class.run do |task3|
              expect(described_class.current).not_to eq(task1)
              expect(described_class.current).not_to eq(task2)
              expect(described_class.current).to eq(task3)
            end

            expect(described_class.current).not_to eq(task1)
            expect(described_class.current).to eq(task2)
          end

          expect(described_class.current).to eq(task1)
        end
      end
    end
  end
end
