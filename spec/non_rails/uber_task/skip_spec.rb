# frozen_string_literal: true

describe UberTask do
  describe '.skip' do
    shared_examples 'skips the task' do
      it 'skips the task' do
        task_skipped = true
        on_skip_called = false

        UberTask.run do
          UberTask.on_skip do
            on_skip_called = true
          end

          subject

          task_skipped = false
        end

        expect(task_skipped).to be(true)
        expect(on_skip_called).to be(true)
      end
    end

    context 'with block' do
      subject { described_class.skip { 'skip reason' } }

      it_behaves_like 'skips the task'
    end

    context 'without block' do
      subject { described_class.skip }

      it_behaves_like 'skips the task'
    end
  end
end
