# Changelog

## [1.0.3] - 2026-11-08

### Fixed
- Rename internal helper functions to singular PowerShell nouns.
- Remove the unused `Name` parameter from the version-check helper.
- Replace `Write-Host` in the CLI presentation layer with a capturable success-stream string.
- Add comment-based help and output type metadata for module functions.
- Fix GitHub Actions static-analysis invocation to analyze files one at a time; include tests and fail on warnings/errors.
- Add CLI human-readable and JSON output smoke tests.
- Update tests to call the singularly named recommendation helper.


## [1.0.2] - 2026-11-08

### Fixed
- Recompute the module path inside Pester `BeforeAll`, because Pester 6 runs setup blocks in a separate scope and does not retain the file-scope `$modulePath` variable.
- Fail with a direct, actionable error if the module file is missing.

## [1.0.1] - 2026-11-08

### Fixed
- Load the module during test discovery so Pester can resolve `InModuleScope`.

## [1.0.0] - 2026-11-08

### Added
- Read-only Node.js and npm diagnostics for Windows PowerShell.
- PATH and common installation-location detection.
- Structured JSON output and actionable recommendations.
- Pester tests, documentation, and GitHub Actions workflow.
