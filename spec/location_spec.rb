# frozen_string_literal: true

require 'pathname'

module UberTask
  describe Location do
    it 'shortens paths' do
      project_root = Pathname.new('/some-project')
      stub_const('Rails', double(root: project_root))

      shortened = [
        project_root.join('foo').to_s,
        '/something/gems/bar',
        '/something/rubygems/baz',
      ].map do |path|
        Location.new(
          path: path,
          line: 42,
        ).path
      end

      expect(shortened).to eq(
        %w[
          [PROJECT]/foo
          [GEM]/bar
          [GEM]/baz
        ],
      )
    end
  end
end
