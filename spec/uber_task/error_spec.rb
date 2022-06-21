# frozen_string_literal: true

describe UberTask::Error do
  it 'inherits from RuntimeError' do
    expect(described_class.superclass).to be(RuntimeError)
  end
end
