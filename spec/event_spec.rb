# frozen_string_literal: true

describe UberTask::Event do
  subject(:event) { described_class.new('Some Event') }

  it 'has name' do
    expect(event.name).to eq('Some Event')
  end

  describe '#handled' do
    it 'raises EventHandled' do
      expect { event.handled }.to raise_error(UberTask::EventHandled)
    end
  end
end
