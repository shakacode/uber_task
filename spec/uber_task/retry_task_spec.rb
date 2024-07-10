# frozen_string_literal: true

describe UberTask::RetryTask do
  subject(:exception) do
    described_class.new(
      reason: 'Some Reason',
      wait: 42,
    )
  end

  it 'inherits from Exception' do
    expect(described_class.superclass).to be(Exception)
  end

  it 'has a reason' do
    expect(exception.reason).to eq('Some Reason')
  end

  it 'has a wait attribute' do
    expect(exception.wait).to eq(42)
  end

  it 'has 0 as a default wait attribute value' do
    expect(described_class.new.wait).to eq(0)
  end

  it 'has a message' do
    expect(exception.message).to eq('Requested to retry the task.')
  end

  describe 'wait attribute validations' do
    it 'does not allow non-numeric value' do
      expect do
        described_class.new(wait: 'string')
      end.to raise_error(ArgumentError, '`wait` is not numberic')
    end

    it 'does not allow negative value' do
      expect do
        described_class.new(wait: -1)
      end.to raise_error(ArgumentError, '`wait` cannot be negative')
    end
  end
end
