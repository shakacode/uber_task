# frozen_string_literal: true

require 'tmpdir'

describe RailsManager do
  let(:manager) { described_class.new(config, app_path: app_path) }

  let(:config) { double }
  let(:app_path) { File.join(tmp_dir, 'test/dummy') }

  after do
    FileUtils.remove_entry(tmp_dir)
  end

  describe '#on_rails', skip: 'Conflicts with manager in rspec_settings' do
    it 'runs isolated code as if on Rails application' do
      ### 1st run
      #
      expect(Dir.exist?(app_path)).to eq false
      expect(defined?(Rails)).to be_nil
      expect(config.instance_variable_defined?(:@rails)).to eq false

      manager.on_rails do
        expect(defined?(Rails)).not_to be_nil
      end

      expect(Dir.exist?(app_path)).to eq true
      expect(defined?(Rails)).to be_nil
      expect(config.instance_variable_defined?(:@rails)).to eq true

      ### 2nd run
      #
      manager.on_rails do
        expect(defined?(Rails)).not_to be_nil
        expect(Rails).to eq config.instance_variable_get(:@rails)
      end

      expect(Dir.exist?(app_path)).to eq true
      expect(defined?(Rails)).to be_nil
      expect(config.instance_variable_defined?(:@rails)).to eq true
    end
  end

  def tmp_dir
    @tmp_dir ||= Dir.mktmpdir
  end
end
