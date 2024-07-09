# frozen_string_literal: true

require 'pathname'

describe UberTask::Internal::Path do
  describe '.shorten' do
    let(:paths) do
      [
        '/foo/bar/baz/gems/bar',
        '/foo/bar/rubygems/baz',
      ]
    end

    it 'shortens paths' do
      shortened = paths.map do |path|
        described_class.shorten(path)
      end
      expect(shortened).to eq(
        %w[
          [GEM]/bar
          [GEM]/baz
        ],
      )
    end
  end
end
