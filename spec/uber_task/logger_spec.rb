# frozen_string_literal: true

describe UberTask do
  before do
    described_class.instance_variable_set(:@logger, nil)
  end

  describe '.logger' do
    it 'memoizes variable' do
      initialized_logger = described_class.logger

      expect(described_class.logger.object_id).to eq(
        initialized_logger.object_id,
      )
    end

    context 'when Rails logger is not defined' do
      it 'uses stdout logger by default' do
        expect do
          described_class.logger.info('some message')
        end.to output(/some message/).to_stdout
      end
    end
  end

  describe '.logger=' do
    it 'changes logger' do
      old_logger = described_class.logger
      new_logger = Logger.new($stderr)

      described_class.logger = new_logger

      expect(described_class.logger).to eq(new_logger)
      expect(described_class.logger).not_to eq(old_logger)
    end
  end
end
