# frozen_string_literal: true

require 'stringio'

require_relative '../../rakelib/release/versions'

RSpec.describe UberTaskRelease::Versions do
  let(:notes) { "### [Unreleased]\n\n#### Fixed\n\n- Repair retries.\n\n" }

  it 'does not silently promote a prerelease through patch fallback' do
    expect do
      described_class.resolve('', '1.0.0.rc.0', notes)
    end.to raise_error(UberTaskRelease::Error, /explicit version/)
  end

  it 'selects a prepared changelog version using the existing heading format' do
    changelog = "#{notes}### [1.0.0.rc.1]\n\n- Prepared release.\n"
    expect(described_class.resolve('', '1.0.0.rc.0', changelog))
      .to eq('1.0.0.rc.1')
  end

  it 'rejects shell fragments as versions' do
    expect do
      described_class.resolve('1.0.0;echo secret', '0.1.0', notes)
    end.to raise_error(UberTaskRelease::Error, /Invalid version/)
  end

  it 'rejects ambiguous flags rather than starting a live release' do
    expect(described_class.flag('TRUE')).to eq(true)
    expect(described_class.flag(nil)).to eq(false)
    expect { described_class.flag('tru') }
      .to raise_error(UberTaskRelease::Error, /true or false/)
  end

  it 'keeps same-version prepared notes authoritative for recovery' do
    changelog = "### [1.0.0.rc.1]\n\n- Existing notes.\n"
    expect(described_class.resolve('', '1.0.0.rc.1', changelog))
      .to eq('1.0.0.rc.1')
  end

  it 'uses new Unreleased notes after the current version has been tagged' do
    changelog = "#{notes}### [0.1.0]\n\n- Released notes.\n"
    expect(described_class.resolve('', '0.1.0', changelog,
                                   tags: ['v0.1.0'])).to eq('0.1.1')
  end

  it 'prefers a newer prepared section even with pending Unreleased notes' do
    changelog = "#{notes}### [0.2.0]\n\n- Prepared notes.\n"
    expect(described_class.resolve('', '0.1.0', changelog,
                                   tags: ['v0.1.0'])).to eq('0.2.0')
  end

  it 'does not promote a tagged prerelease with new Unreleased notes' do
    changelog = "#{notes}### [1.0.0.rc.0]\n\n- Released notes.\n"
    expect do
      described_class.resolve('', '1.0.0.rc.0', changelog,
                              tags: ['v1.0.0.rc.0'])
    end.to raise_error(UberTaskRelease::Error, /explicit version/)
  end

  it 'uses patch fallback only for a stable version' do
    expect(described_class.resolve('', '0.1.0', notes)).to eq('0.1.1')
    expect(described_class.resolve('minor', '1.0.0.rc.0', notes)).to eq('1.1.0')
    expect(described_class.resolve('major', '1.0.0.rc.0', notes)).to eq('2.0.0')
  end

  it 'moves Unreleased notes while preserving other versions' do
    changelog = "#{notes}### [0.1.0]\n\n- Original notes.\n"
    prepared = described_class.prepare(changelog, '0.1.1')
    expect(described_class.section(prepared, 'Unreleased'))
      .to eq('_Nothing yet._')
    expect(described_class.section(prepared,
                                   '0.1.1')).to include('Repair retries')
    expect(described_class.section(prepared,
                                   '0.1.0')).to eq('- Original notes.')
  end

  it 'refuses missing and empty release notes' do
    ['', "### [0.1.1]\n\n_Nothing yet._\n"].each do |changelog|
      expect { described_class.prepare(changelog, '0.1.1') }
        .to raise_error(UberTaskRelease::Error)
    end
  end

  it 'does not count the existing Unreleased template sentence as notes' do
    changelog = "### [Unreleased]\n\n" \
                "Changes since the last non-beta release.\n\n_Nothing yet._\n"
    expect { described_class.prepare(changelog, '0.1.1') }
      .to raise_error(UberTaskRelease::Error, /meaningful/)
    prepared = described_class.prepare(
      changelog.sub('_Nothing yet._', '- Actual release note.'), '0.1.1'
    )
    expect(prepared).not_to include('Changes since the last non-beta release.')
  end

  it 'matches hyphen prerelease headings to normalized versions' do
    changelog = "### [Unreleased]\n\n_Nothing yet._\n\n" \
                "### [1.0.0-rc.1]\n\n- Prepared prerelease.\n"
    version = described_class.resolve('', '1.0.0.pre.rc.0', changelog)
    expect(version).to eq('1.0.0.pre.rc.1')
    expect(described_class.prepare(changelog, version)).to eq(changelog)
    expect(described_class.section(changelog, version))
      .to eq('- Prepared prerelease.')
  end

  it 'blocks old versions even when the policy override is enabled' do
    expect do
      described_class.validate!(
        '0.1.1', ['v0.2.0'], notes, override: true, output: StringIO.new
      )
    end.to raise_error(UberTaskRelease::Error, /older than latest tag/)
  end

  it 'requires and reports an explicit changelog bump override' do
    output = StringIO.new
    expect do
      described_class.validate!(
        '0.2.0', ['v0.1.0'], notes, override: false, output: output
      )
    end.to raise_error(UberTaskRelease::Error, /Changelog implies patch/)
    described_class.validate!(
      '0.2.0', ['v0.1.0'], notes, override: true, output: output
    )
    expect(output.string).to include('VERSION POLICY OVERRIDE')
  end
end
