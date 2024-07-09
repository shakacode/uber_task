# frozen_string_literal: true

require 'pathname'

describe UberTask::Internal::Path do
  describe '.shorten' do
    context 'normal' do
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

    context 'on rails', :on_rails do
      let(:paths) do
        [
          Rails.root.join('abc').to_s,
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
            [PROJECT]/abc
            [GEM]/bar
            [GEM]/baz
          ],
        )
      end
    end
  end
end
