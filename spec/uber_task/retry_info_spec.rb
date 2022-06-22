# frozen_string_literal: true

describe UberTask::RetryInfo do
  subject(:no_args) { described_class.new }

  subject(:info) do
    described_class.new(
      default_retries: 12,
      default_retry_wait: 34,
      retries: 56,
    )
  end

  subject(:no_default_wait) do
    described_class.new(
      default_retries: 12,
      default_retry_wait: 0,
      retries: 34,
    )
  end

  context 'when no argument is supplied' do
    it 'uses default values' do
      expect(no_args.default_retries).to eq(0)
      expect(no_args.default_retry_wait).to eq(0)
      expect(no_args.report).to eq(true)
      expect(no_args.retries).to eq(0)
      expect(no_args.retries_remaining).to eq(0)
      expect(no_args.wait).to eq(0)
    end
  end

  it 'is initialized' do
    expect(info.default_retries).to eq(12)
    expect(info.default_retry_wait).to eq(34)
    expect(info.report).to eq(true)
    expect(info.retries).to eq(56)
    expect(info.retries_remaining).to eq(56)
    expect(info.wait).to eq(0)
  end

  describe '#message' do
    context 'with arguments' do
      it 'returns the retry message' do
        message1 = info.message(wait: 42)
        expected1 = <<~MSG.strip
          Retrying in 42 seconds... (56 retries remaining)
        MSG

        info.retries_remaining -= 1
        message2 = info.message(wait: 42)
        expected2 = <<~MSG.strip
          Retrying in 42 seconds... (55 retries remaining)
        MSG

        message3 = no_default_wait.message(wait: 42)
        expected3 = <<~MSG.strip
          Retrying in 42 seconds... (34 retries remaining)
        MSG

        expect(message1).to eq(expected1)
        expect(message2).to eq(expected2)
        expect(message3).to eq(expected3)
      end
    end

    context 'without arguments' do
      it 'returns the retry message' do
        message1 = info.message
        expected1 = <<~MSG.strip
          Retrying in 34 seconds... (56 retries remaining)
        MSG

        info.retries_remaining -= 1
        message2 = info.message
        expected2 = <<~MSG.strip
          Retrying in 34 seconds... (55 retries remaining)
        MSG

        message3 = no_default_wait.message
        expected3 = <<~MSG.strip
          Retrying... (34 retries remaining)
        MSG

        expect(message1).to eq(expected1)
        expect(message2).to eq(expected2)
        expect(message3).to eq(expected3)
      end
    end
  end
end
