# frozen_string_literal: true

describe UberTask do
  before do
    described_class.instance_variable_set(:@logger, nil)
  end

  describe '.logger' do
    subject(:logger) { described_class.logger }

    it 'uses stdout logger by default' do
      expect do
        logger.info('some message')
      end.to output(/some message/).to_stdout
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
