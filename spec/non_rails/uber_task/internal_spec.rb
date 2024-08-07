# frozen_string_literal: true

describe UberTask::Internal do
  describe '.trace' do
    context 'when tracing is not defined' do
      before do
        Thread.current[:__uber_task_trace__] = nil
      end

      it 'ignores the trace' do
        expect do
          described_class.trace do
            raise 'This should not be raised'
          end
        end.not_to raise_error
      end
    end

    context 'when tracing is disabled' do
      before do
        UberTask.disable_tracing
      end

      it 'ignores the trace' do
        expect do
          described_class.trace do
            raise 'This should not be raised'
          end
        end.not_to raise_error
      end
    end

    context 'when tracing is enabled' do
      before do
        UberTask.enable_tracing
      end

      it 'logs the trace message via logger\'s debug level' do
        expect(UberTask.logger).to receive(:debug).with('some message')

        described_class.trace { 'some message' }
      end
    end
  end
end
