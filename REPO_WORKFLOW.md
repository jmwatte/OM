# Repository workflow — single-developer policy

**Policy:** This repository is maintained by a single developer. We do **not** use GitHub Pull Requests (PRs), PR-based review, or PR gating. GitHub is used only as a remote file store.

**Workflow:**
- Changes are committed locally and pushed directly to the `master` branch.
- Keep commits small and descriptive.
- If external contributions are accepted in the future, this policy should be re-evaluated and documented here.

**Note for automation / tools:**
- Automation or assistants should not create or rely on PR workflows for changes to this repository unless this policy is explicitly changed.

**Integration tests:**
- Some integration tests require isolated environments and may start child processes or interact with the filesystem in ways that can hang under the automated test harness (Pester runspace). These tests are intentionally marked `-Skip` to avoid blocking automated runs.
- To run integration tests locally:
  - Run the integration test(s) directly in an interactive PowerShell session (not within the CI harness):
    `pwsh -NoProfile -Command "Import-Module .\OM.psm1; Invoke-Pester -Script .\Private\Tests\Integration\Move-Album.Integration.Tests.ps1 -Verbose -RunInIsolation"`
  - If needed, create a sandbox (copy `testfiles` to a temporary directory) and run the specific Move/Move-AlbumFolder flows there.
- If you fix or stabilize an integration test, re-enable it by removing `-Skip` and add notes to this file describing why it is now safe in CI.

_Added by automation on 2026-01-04 (integration tests guidance)._
