# Update Changelog

Add missing entries to `CHANGELOG.md` for the UberTask gem (`shakacode/uber_task`)
and, when asked, start the release preparation for a version.

## Arguments

`$ARGUMENTS` selects the mode:

- **No argument** (`/update-changelog`): add entries for merged PRs under
  `### [Unreleased]`. Use this as PRs merge.
- **`release`**, **`rc`**, or **`beta`**: add entries, compute the next version,
  confirm it with the user, then start release preparation.
- **Explicit version** (`/update-changelog 1.0.0.rc.2`): the same, with that exact
  RubyGems version instead of a computed one.

`bundle exec rake release` owns version stamping. It moves the Unreleased notes
into `### [VERSION] - YYYY-MM-DD`, bumps `lib/uber_task/version.rb`, and opens
the preparation PR. Never hand-write the heading for the version being
released. [docs/releasing.md](../../docs/releasing.md) describes the release
process this command feeds.

## What belongs in the changelog

Add an entry only for a change a gem user can observe: features, bug fixes,
breaking changes, deprecations, performance, security, and changes to the public
API or to supported Ruby and Rails versions.

Skip linting, formatting, refactoring, tests, CI, release tooling, and agent
instructions. Skip documentation unless it corrected a wrong description of
behavior. When a revert landed, drop or rewrite the entry it undoes.

## Format

```markdown
### [Unreleased]

#### Fixed

- **Retry counts no longer leak between tasks**. [PR 41](https://github.com/shakacode/uber_task/pull/41) by [justin808](https://github.com/justin808).
```

- Version headings use three hashes and categories use four. The release task
  reads both, so keep them exact.
- Use these categories, in this order, and only those that have entries:
  `#### Breaking Changes`, `#### Added`, `#### Changed`, `#### Fixed`,
  `#### Deprecated`, `#### Removed`, `#### Security`.
- Start each entry with a bold description in past tense that ends with a period.
  Link the PR as `[PR 41](...)` without a hash sign, then link the author.
- Open a breaking change with `BREAKING CHANGE:` and say what callers must change.
- An empty Unreleased section holds `_Nothing yet._`. Replace that placeholder
  with the first entry; the release task puts it back.
- Entries before this format have no PR links. Leave them as they are.
- End the file with a newline.

## Steps

1. Run `git fetch origin main --tags` and compare against `origin/main`, never a
   local branch.
2. Reconcile tags with sections. Every stable `v*` tag needs a `### [VERSION]`
   section. A prerelease tag needs one until its entries are folded into its
   stable release, as described under "Stable release after prereleases"; ask
   the user before recreating a prerelease section that may have been folded.
   For a tag that lacks its section, add `### [VERSION] - DATE` above the
   previous version, dated with `git log -1 --format=%cs TAG`. Fill it from the
   user-visible PRs in `PREVIOUS_TAG..TAG`, and move in any Unreleased entries
   that shipped in it. This is the one case where you write a version heading
   yourself.
3. List the PRs merged since the latest tag with
   `git log --first-parent --oneline LATEST_TAG..origin/main`. Squash merges end
   in `(#N)`.
4. For each PR the changelog does not mention, read it with
   `gh pr view N --repo shakacode/uber_task --json title,body,author`. Take PR
   details from Git and GitHub; never ask the user for them. Decide whether it
   belongs, then add its entry under the right category in `### [Unreleased]`.
5. Check the result: no category heading appears twice in one section, versions
   run newest first, and nothing outside the changelog changed.
6. Report the entries added and the PRs skipped, each with its reason.

With no argument, stop here: commit the changelog on a feature branch and open
a PR.

## Version modes

1. Find the target `X.Y.Z` from tags, newest first:
   `git tag -l 'v*' --sort=-v:refname | head`. When the newest tag is a
   prerelease `vX.Y.Z.rc.N` or `vX.Y.Z.beta.N` and no `vX.Y.Z` tag exists, that
   series is active and `X.Y.Z` is the target.
2. Otherwise apply a bump to the latest stable tag. Pick it from the Unreleased
   categories: Breaking Changes means major, Added means minor, and anything
   else means patch. The release task enforces the same rule for stable
   versions.
3. Compute the version in RubyGems form. `release` uses `X.Y.Z`. `rc` and `beta`
   append the next index for that target, counted from tags only:
   `git tag -l 'vX.Y.Z.rc.*'`. A new series starts at index 0, as `v1.0.0.rc.0`
   did. A changelog heading is a draft, not a shipped version. Write
   `1.0.0.rc.1`, never `1.0.0-rc.1`.
4. Show the version and your reasoning, and wait for the user to confirm it. Say
   so when the bump is a judgment call.
5. If the steps above changed `CHANGELOG.md`, open the changelog PR and stop.
   Preparation reads the changelog from `main`, so those entries must merge
   first. Ask the user to run this command again afterwards.
6. Otherwise, from a clean `main` that matches `origin/main`, run the dry run.
   It pushes nothing, tags nothing, and uploads nothing:

   ```sh
   bundle exec rake "release[VERSION,true]"
   ```

   Continue only when it ends with `would open a preparation PR`. If it ends
   with `would publish after exact CI`, the version is already prepared on
   `main` and the same command without the dry-run flag would publish it. Stop
   and tell the user. If the task reports that the changelog implies a different
   bump, explain the mismatch, and pass `true` as the third argument only after
   the user accepts the override.
7. Open the preparation PR:

   ```sh
   bundle exec rake "release[VERSION]"
   ```

8. Report the preparation PR and stop. Publishing is the maintainer's step:
   after that PR merges, they update `main` and run
   `bundle exec rake "release[VERSION]"` again. It tags, uploads to RubyGems
   with their OTP, and creates the GitHub release. Never run that step yourself.

## Stable release after prereleases

Before stamping `X.Y.Z` when `X.Y.Z.rc.N` or `X.Y.Z.beta.N` sections exist, fold
them into Unreleased in a changelog PR:

- Move their entries under the Unreleased categories and merge duplicate
  headings.
- Drop fixes for bugs that only ever existed in a prerelease, and keep only the
  final description of a feature that changed between prereleases.
- Keep every breaking change, and every fix for a bug that shipped in the last
  stable version.
- Delete the emptied prerelease sections, and say in the PR description that
  they were folded. Each prerelease keeps its own GitHub release notes, because
  those are read from the changelog at its tag.

Read the result as someone upgrading from the previous stable version. After
that PR merges, continue with the version modes above. The reconcile step then
leaves the folded prerelease tags without sections.
