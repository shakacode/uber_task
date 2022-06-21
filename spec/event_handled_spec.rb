# frozen_string_literal: true

describe UberTask::EventHandled do
  it 'inherits from Exception' do
    expect(described_class.superclass).to be(Exception)
  end
end
