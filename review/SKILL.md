---
name: npp-review
description: Review a change in Pyre909's Notepad++ fork before pushing it or opening a pull request: a branch for upstream Notepad++ (<topic>_<YYYYMMDD>) or pyre. Runs the review harness (upstream rules, line endings, coding style, localization, MSVC builds, app-level tests), then an independent AI review against the review checklist, verifies every finding and reports. Use when asked to review, check or validate code in this fork, or before any push of a pull request branch.
---

# Reviewing a change in the Notepad++ fork

The harness is on the tooling branch, in `%USERPROFILE%\src\npp.worktrees\scintilla-upstream_20260930\review\`
(`git pull` there first). Its `README.md` explains every check, `checklist.md` is the AI review.

1. **Scope.** Find the worktree and branch under review. A pull request branch is compared with `upstream/master`,
   `pyre` with `origin/pyre`. Write one paragraph on what the change is for.

2. **Harness.** From PowerShell 7:

   ```powershell
   pwsh -File <review>\review.ps1 -Path <worktree> -Build ARM64,x64,Win32 -Test <name>|All
   ```

   Every FAIL gets fixed. Every WARN gets fixed or explained. If the change has behaviour that a test can prove,
   add or extend a test in `<review>\tests\` (contract in the README) and run it with `-Test`.

3. **Independent AI review.** Launch one reviewer agent (Explore, very thorough, read-only) with: the worktree path,
   `git diff <base>` as the scope, the paragraph from step 1, and the content of `checklist.md`. Don't give it your
   own conclusions or the harness results. For a large change, split the checklist areas across two or three
   agents. While it works, do your own pass through the checklist.

4. **Verify before acting.** For each finding, reproduce it or show the code path. Fix the real ones (smallest
   change that follows upstream's style), rerun step 2, and add a test when the fix changes behaviour. Note the
   findings you reject and why.

5. **Report.** A verdict; the findings fixed, with evidence; the findings rejected, with the reason; what the
   harness and the tests showed; what was not tested and why.

Never push, open a pull request, or post anything without the user's OK. Pull request branches: one commit (amend
until the pull request is opened, then new commits only), the AI use disclosed in the pull request.
