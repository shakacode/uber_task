# Contributing Guidelines

Thank you for your interest in contributing to UberTask! We welcome all contributions that align with our project goals and values. To ensure a smooth and productive collaboration, please follow these guidelines.

## Contents

- [Reporting Issues](#reporting-issues)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Setting Up a Development Environment](#setting-up-a-development-environment)
- [Making Sure Your Changes Pass All Tests](#making-sure-your-changes-pass-all-tests)
- [Linting and Code Quality](#linting-and-code-quality)

## Reporting Issues

If you encounter any issues with the project, please first check the existing issues (including closed ones). If the issue has not been reported before, please open an issue on our GitHub repository. Please provide a clear and detailed description of the issue, including steps to reproduce it.

If looking to contribute to the project by fixing existing issues, we recommend looking at issues, particularly with the "[help wanted](https://github.com/shakacode/uber_task/issues?q=is%3Aissue+label%3A%22help+wanted%22)" label.

## Submitting Pull Requests

We welcome pull requests that fix bugs, add new features, or improve existing ones. Before submitting a pull request, please make sure to:

- Open an issue about what you want to propose before starting work.
- Fork the repository and create a new branch for your changes.
- Write clear and concise commit messages.
- Follow our code style guidelines.
- Write tests for your changes and [make sure all tests pass](#making-sure-your-changes-pass-all-tests).
- Update the documentation as needed.
- Update CHANGELOG.md if the changes affect public behavior of the project.

## Setting Up a Development Environment

1. Clone the repository:
   ```bash
   git clone https://github.com/shakacode/uber_task.git
   cd uber_task
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Run the tests to ensure everything is set up correctly:
   ```bash
   bundle exec rspec
   ```

## Making Sure Your Changes Pass All Tests

There are several specs covering different aspects of UberTask. You may run them locally or rely on GitHub CI actions configured to test the gem functionality in different Ruby environments.

We request running tests locally to ensure new changes would not break the CI build.

### 1. Check the code for Ruby style violations

```bash
bundle exec rubocop
```

### 2. Run the Ruby test suite

```bash
bundle exec rspec
```

### 3. Run a single test file

```bash
bundle exec rspec spec/uber_task/task_context_spec.rb
```

### 4. Run a single test

```bash
bundle exec rspec -e "runs a simple task"
```

### 5. Run all checks (default rake task)

```bash
bundle exec rake
```

This runs both RuboCop and RSpec.

## Linting and Code Quality

This project uses RuboCop for Ruby linting and code style enforcement.

### Running Linters

```bash
# Run RuboCop
bundle exec rubocop

# Run RuboCop with auto-fix
bundle exec rubocop -a
```

## Git Hooks (Optional)

This project includes configuration for git hooks via `lefthook`. They are **opt-in for contributors**.

To enable pre-commit hooks locally:

```bash
lefthook install
```

## Releasing

Releases are managed by project maintainers. See `rakelib/release.rake` for the release process.

The release task handles:
- Version bumping
- Git tagging
- Gem publishing to RubyGems

To create a release (maintainers only):

```bash
# Bump patch version and release
rake release[patch]

# Bump minor version and release
rake release[minor]

# Bump major version and release
rake release[major]

# Set explicit version and release
rake release[0.2.0]

# Dry run (no actual release)
rake release[patch,true]
```
