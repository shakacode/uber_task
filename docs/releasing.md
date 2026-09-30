# Release UberTask

Use `bundle exec rake release` to prepare a version through a PR, then run the
same command from the updated destination branch to publish that merged version.
The workflow uses Ruby, Bundler, `gem-release`, Git, and authenticated GitHub CLI.
It never pushes `main` or publishes to a second package registry.

## Prepare and review

Write meaningful release notes under `### [Unreleased]` in `CHANGELOG.md` and
merge them first. Alternatively, prepare a `### [VERSION]` section. Preserve the
existing three-hash heading format; subsections use four hashes.

From a clean, current `main` checkout:

```sh
bundle exec rake "release[1.0.0.rc.1,true]" # Unattended dry run
bundle exec rake "release[1.0.0.rc.1]"      # Open a preparation PR
```

A new version creates `prepare-release/vVERSION` in an independent temporary
clone. The task bumps the version, moves Unreleased notes into a versioned
section, updates dependencies, builds the gem, and runs the project's RSpec and
RuboCop validation before pushing that feature branch and creating its PR.
Only the version file, changelog, and an already tracked lockfile are staged.
UberTask currently ignores `Gemfile.lock`; it stays untracked, and dependency
installation happens in the temporary clone. The caller's checkout stays intact.
Merge the preparation PR through the repository's normal review requirements.
No tag, gem, or GitHub release is published during preparation.

With no argument, the latest versioned changelog section supplies the version
when it is newer, or current with no new Unreleased notes after tagging. A tagged
current version with meaningful Unreleased notes falls back to a patch bump,
as does an older or absent versioned section. A prerelease never silently becomes
stable through patch fallback: specify the target explicitly. `patch`, `minor`,
and `major` are supported; versions use RubyGems syntax, such as `1.0.0.rc.1`.
RubyGems normalizes hyphen prereleases; all tags use `v` plus the normalized version.

Versions cannot downgrade the checkout or fall behind fetched release tags.
For stable versions, Breaking notes imply major, Added/Features imply minor,
and Fixed/Security/Changed/Removed/Deprecated imply patch. An intentional mismatch
requires the third argument and prints `VERSION POLICY OVERRIDE`:

```sh
bundle exec rake "release[1.0.0,true,true]" # Preview an explicit policy override
```

That flag never bypasses commit, CI, tag, or artifact identity gates. Flags accept
`true` or `false` (case insensitive); other values fail rather than starting a
live release accidentally. Missing or empty release notes block preparation.

## Publish the merged version

Update `main` after merging the preparation PR, then use its explicit version:

```sh
bundle exec rake "release[1.0.0.rc.1]"
# For a stable release, after its own preparation PR:
bundle exec rake "release[1.0.0]"
```

Stable publication requires `main`. Prereleases may use `main` or an existing
`release/*` destination branch; merge preparation into that branch first.
Preparation branches and arbitrary feature branches cannot publish. The selected
commit must match the live remote branch. Both official GitHub Actions checks
named `RSpec` and `Rubocop` must succeed on that exact commit. Missing, pending,
failed, cancelled, skipped, stale, or impersonated checks block publication.
There is no CI override. After any new commit or refresh, rerun and wait for that
commit's checks; earlier green checks do not carry forward.

The task builds with the commit's timestamp, publishes only `vVERSION`, uploads
only the verified gem to RubyGems.org, then creates or updates GitHub notes from
the changelog **at that tag**. Prerelease state follows the RubyGems version.
Existing local/remote tags pointing to another commit are never overwritten.

RubyGems MFA remains required. Supply `RUBYGEMS_OTP` or enter an OTP when prompted
(terminal input is hidden). OTPs use the RubyGems subprocess environment instead
of command arguments, shell strings, or log text. Only OTP/MFA and recognized transient publication failures
can retry, with a fresh OTP; `GEM_RELEASE_MAX_RETRIES` must be 1–3. Git and GitHub
mutations do not retry automatically.

## Recover the same version

Failures report completed publication steps. Keep the explicit version when
retrying so recovery cannot become another patch release:

```sh
bundle exec rake "release[1.0.0.rc.1]"
bundle exec rake "sync_github_release[1.0.0.rc.1,true]" # Preview notes only
bundle exec rake "sync_github_release[1.0.0.rc.1]"      # Create/update notes only
```

An existing RubyGems version is skipped only when its published SHA-256 matches
the rebuilt artifact. A different or unavailable checksum blocks recovery; inspect
the original commit, build environment, and published artifact before continuing.
Do not delete or move published tags to work around a conflict. A push can have
succeeded even if its response or subsequent verification failed; retry the same
version and let the task establish publication state before another upload.

Notes synchronization verifies the existing remote tag and its committed version
and notes. It neither bumps the version nor uploads a gem. If a preparation branch
was pushed but PR creation failed, create the PR for that existing branch instead
of rerunning preparation or force pushing it.

Dry runs use an independent temporary clone, including independent refs and tags.
They exercise version selection, preparation, and gem building without prompts or
remote writes. They require normal read access and installed dependencies, but
never push branches/tags, upload gems, or create/edit releases. Success and failure
leave caller tracked files, lockfile, index, branch, and tags unchanged. No dry-run
result claims that the future merged release commit has passed publication CI.
