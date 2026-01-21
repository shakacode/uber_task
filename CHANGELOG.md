# Change Log

All notable changes to this project will be documented in this file. Items under `Unreleased` are upcoming features that will be out in the next version.

## Contributors

Please follow the recommendations outlined at [keepachangelog.com](http://keepachangelog.com/). Please use the existing headings and styling as a guide.

## Versions

### [Unreleased]

Changes since the last non-beta release.

_Nothing yet._

### [0.1.0] - 2022-06-16

#### Added

- Initial release with core sequential task management functionality
- `UberTask.run` method for creating and running tasks with configurable retry options
- Event handlers: `on_success`, `on_report`, `on_skip`, `on_subtask_error`, `on_retry`
- Retry mechanism with configurable retry count and wait time
- Progress reporting via `UberTask.report`
- Task skipping via `UberTask.skip`
- Support for vital and non-vital tasks
- Colorized console output for task progress
