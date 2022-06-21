# frozen_string_literal: true

describe UberTask::SkipTask do
  subject(:exception) do
    described_class.new(reason: 'Some Reason')
  end

  it 'inherits from Exception' do
    expect(described_class.superclass).to be(Exception)
  end

  it 'has a reason' do
    expect(exception.reason).to eq('Some Reason')
  end

  it 'has a message' do
    expect(exception.message).to eq('Requested to skip the task.')
  end
end
