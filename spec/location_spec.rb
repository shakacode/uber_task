# frozen_string_literal: true

require 'pathname'

module UberTask
  describe Location do
    describe '#path' do
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

        it 'shortens paths' do
          shortened = paths.map do |path|
            Location.new(
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

        it 'shortens paths' do
          shortened = paths.map do |path|
            Location.new(
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
    end
  end
end
