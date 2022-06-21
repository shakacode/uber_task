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

  it 'has a message' do
    expect(exception.message).to eq('Requested to retry the task.')
  end
end
