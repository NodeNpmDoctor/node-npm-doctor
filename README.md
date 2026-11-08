# Node.js & npm Doctor

A small, read-only PowerShell diagnostic for checking whether Node.js and npm are installed, discoverable on `PATH`, and able to report their versions on Windows.

## Features

- Finds `node.exe` and `npm.cmd`/`npm.exe` available on `PATH`.
- Checks common installation locations, including the standard Node.js folder, per-user installation folder, NVM symlink, and Volta bin folder.
- Distinguishes `Available`, `FoundButNotOnPath`, and `NotFound` states.
- Executes only the version checks (`--version`) for discovered commands.
- Prints actionable recommendations.
- Supports structured JSON output for diagnostics and automation.
- Does not install software, change `PATH`, edit registry values, or write diagnostic files.

## Requirements

- Windows 10 or later (the script may also work in Windows PowerShell 5.1 on earlier supported Windows versions).
- Windows PowerShell 5.1 or PowerShell 7+.
- No third-party runtime is required to run the diagnostic.

## Quick start

From PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\NodeNpmDoctor.ps1
```

JSON output:

```powershell
.\scripts\NodeNpmDoctor.ps1 -Json
```

Return a failing PowerShell exit status when either tool is missing from `PATH` or a version check fails:

```powershell
.\scripts\NodeNpmDoctor.ps1 -FailOnMissing
```

Combine options:

```powershell
.\scripts\NodeNpmDoctor.ps1 -Json -FailOnMissing
```

## Status values

| Status | Meaning |
|---|---|
| `Available` | The executable was discovered on `PATH`. |
| `FoundButNotOnPath` | The executable exists in a recognized installation directory but was not resolved from `PATH`. |
| `NotFound` | No executable was found in `PATH` or the recognized installation locations. |

`Ready` is `true` only when both commands are available on `PATH` and both version checks succeed.

## Safety and privacy

The diagnostic is intentionally read-only. It does not modify environment variables, install or update Node.js/npm, change execution policy, edit the registry, or access credentials.

The report may include local executable paths and system details. Review JSON output before posting it publicly or attaching it to an issue, because local paths can contain your Windows account name or organization details.

The script invokes only `node --version` and `npm --version` on commands it discovers. Do not run software from untrusted installation directories; inspect the reported paths before sharing diagnostic output.

## Tests

Tests use [Pester](https://pester.dev/) 5.0.0 or later (including 6.x). The test file imports the module during discovery for `InModuleScope`, then verifies the module path again inside `BeforeAll`. The CLI emits human-readable text on the success stream so its output can be captured or redirected; JSON mode emits only JSON. The test suite covers module behavior plus both CLI output modes.

```powershell
Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force
Import-Module Pester -MinimumVersion 5.0.0 -Force
Invoke-Pester -Path ./tests -Output Detailed
```

GitHub Actions runs PSScriptAnalyzer (warnings and errors), the Pester suite, and a JSON-output smoke test on `windows-latest`.

## Project layout

```text
src/NodeNpmDoctor/NodeNpmDoctor.psm1  # Diagnostic logic
scripts/NodeNpmDoctor.ps1             # Command-line entry point
tests/NodeNpmDoctor.Tests.ps1         # Pester tests
.github/workflows/test.yml            # Windows CI
```

## License

MIT. See [LICENSE](LICENSE).

## Project history

NodeNpmDoctor is an independent, general-purpose Windows diagnostic tool for checking Node.js and npm availability and environment configuration.
