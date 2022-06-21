# frozen_string_literal: true

require 'pathname'

describe UberTask::Location do
  context 'normal' do
    let(:paths) do
      [
        '/foo/bar/baz/gems/bar',
        '/foo/bar/rubygems/baz',
      ]
    end

    before do
      stub_const('Rails', nil)
    end

    describe '#path' do
      it 'shortens paths' do
        shortened = paths.map do |path|
          described_class.new(
            path: path,
            line: 42,
          ).path
        end
        expect(shortened).to eq(
          %w[
            [GEM]/bar
            [GEM]/baz
          ],
        )
      end
    end

    describe '#to_s' do
      it 'returns the path and line as string' do
        locations = paths.map do |path|
          described_class.new(
            path: path,
            line: 42,
          ).to_s
        end
        expect(locations).to eq(
          %w[
            [GEM]/bar:42
            [GEM]/baz:42
          ],
        )
      end
    end
  end

  context 'in rails' do
    let(:rails_root) { Pathname.new(Dir.pwd) }
    let(:paths) do
      [
        rails_root.join('abc').to_s,
        '/foo/bar/baz/gems/bar',
        '/foo/bar/rubygems/baz',
      ]
    end

    before do
      stub_const('Rails', double(root: rails_root))
    end

    describe '#path' do
      it 'shortens paths' do
        shortened = paths.map do |path|
          described_class.new(
            path: path,
            line: 42,
          ).path
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

    describe '#to_s' do
      it 'returns the path and line as string' do
        locations = paths.map do |path|
          described_class.new(
            path: path,
            line: 42,
          ).to_s
        end
        expect(locations).to eq(
          %w[
            [PROJECT]/abc:42
            [GEM]/bar:42
            [GEM]/baz:42
          ],
        )
      end
    end
  end
end
