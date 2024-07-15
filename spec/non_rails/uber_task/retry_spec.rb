# frozen_string_literal: true

describe UberTask do
  describe '.retry' do
    shared_examples 'retries the task' do
      it 'retries the task' do
        run_count = 0
        on_retry_count = 0

        UberTask.run(retry_count: 3) do
          UberTask.on_retry do
            on_retry_count += 1
          end

          if run_count < 2
            run_count += 1
            subject
          end
        end

        expect(run_count).to be(2)
        expect(on_retry_count).to be(2)
      end
    end

    context 'with block' do
      subject { described_class.retry { 'retry reason' } }

      it_behaves_like 'retries the task'
    end

    context 'without block' do
      subject { described_class.retry }

      it_behaves_like 'retries the task'
    end

    context 'with wait' do
      subject { described_class.retry(wait: 1) }

      it_behaves_like 'retries the task'
    end
  end
end
