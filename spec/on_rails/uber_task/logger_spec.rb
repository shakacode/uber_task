# frozen_string_literal: true

describe UberTask do
  before do
    described_class.instance_variable_set(:@logger, nil)
  end

  describe '.logger' do
    subject(:logger) { described_class.logger }

    it 'uses Rails logger by default' do
      expect(Rails.logger).to receive(:info).with('some message')

      logger.info('some message')
    end
  end
end
