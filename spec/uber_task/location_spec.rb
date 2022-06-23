# frozen_string_literal: true

require 'pathname'

describe UberTask::Location do
  subject(:location) do
    described_class.new(
      path: 'some/path',
      line: 42,
    )
  end

  it 'initializes the attributes' do
    expect(location.path).to eq('some/path')
    expect(location.line).to eq(42)
  end

  it

  describe '#to_s' do
    it 'returns the path and line as string' do
      expect(location.to_s).to eq('some/path:42')
    end
  end
end
