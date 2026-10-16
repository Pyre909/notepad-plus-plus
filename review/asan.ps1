# Memory errors (use after free, buffer overflows, double frees): builds a git ref of the fork with AddressSanitizer
# (MSVC, ARM64, Release) in a worktree of its own, runs the app-level tests on it, and fails on any sanitizer report.
# The Windows counterpart of Valgrind's memcheck; leaks are leaks.ps1's (on a normal build: under the sanitizer, freed
# memory stays in its quarantine, so leaks.ps1 then checks objects and handles only).
#   pwsh -File asan.ps1 -Ref <branch, tag or commit> [-Test All | <name>,...] [-Worktree <folder>]
# What it takes on Windows (found on 2026-10-16):
# - Notepad++ links with /DEPENDENTLOADFLAG:0x800 (static imports from System32 only, against DLL hijacking), so the
#   sanitizer's runtime next to the exe isn't found and the loader waits on an invisible error box: this build is
#   relinked with /DEPENDENTLOADFLAG:0x0 (and /DEBUG, for source lines in reports) through the linker's _LINK_ variable.
# - clang_rt.asan_dynamic-aarch64.dll is copied next to the exe.
# - ASAN_OPTIONS separates options with ':', so a log path with a drive letter is quoted (else the sanitizer can't open
#   its log and exits with code 1).
param([Parameter(Mandatory)] [string] $Ref, [string[]] $Test = @('All'),
	[string] $Worktree = (Join-Path (Split-Path (Split-Path $PSScriptRoot)) 'asan'))
$ErrorActionPreference = 'Stop'
$clone = (& git -C $PSScriptRoot rev-parse --path-format=absolute --git-common-dir).Trim() | Split-Path

# the worktree, on the ref (detached)
if (-not (Test-Path $Worktree)) { & git -C $clone worktree add --detach $Worktree $Ref | Out-Null }
else { & git -C $Worktree checkout --detach --quiet $Ref }
if ($LASTEXITCODE -ne 0) { throw "can't check out $Ref in $Worktree" }
"$Ref at $((& git -C $Worktree log -1 --oneline).Trim()), in $Worktree"

# the build: the Developer environment of Visual Studio (Build Tools 2026), then MSBuild with the sanitizer
$vs = Get-ChildItem 'C:\Program Files*\Microsoft Visual Studio\*\*' -Directory | Where-Object { Test-Path "$($_.FullName)\Common7\Tools\Launch-VsDevShell.ps1" } | Select-Object -First 1
if (-not $vs) { throw 'no Visual Studio found' }
& "$($vs.FullName)\Common7\Tools\Launch-VsDevShell.ps1" -Arch arm64 -HostArch arm64 -SkipAutomaticLocation *> $null
$bin = Join-Path $Worktree 'PowerEditor\binarm64'
$exe = Join-Path $bin 'Notepad++.exe'
if (Test-Path $exe) { [IO.File]::Delete($exe) }  # relinked with _LINK_ even when nothing else changed
$env:_LINK_ = '/DEPENDENTLOADFLAG:0x0 /DEBUG'
$log = Join-Path ([IO.Path]::GetTempPath()) 'npp-asan-build.log'
# another commit than the last build: a full rebuild (objects of another class layout fail to link, or crash)
$commit = (& git -C $Worktree rev-parse HEAD).Trim()
$stamp = Join-Path $Worktree '.asan-built'
$target = if ((Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $commit)) { 'Build' } else { 'Rebuild' }
& msbuild (Join-Path $Worktree 'PowerEditor\visual.net\notepadPlus.sln') /m /nologo /v:m /t:$target /p:Configuration=Release /p:Platform=ARM64 /p:EnableASAN=true *> $log
$built = ($LASTEXITCODE -eq 0) -and (Test-Path $exe)
Remove-Item Env:_LINK_
if (-not $built) { Select-String -Path $log -Pattern ' error ' | Select-Object -First 10 | ForEach-Object { $_.Line.Trim() }; throw "the build failed, see $log" }
$runtime = Get-ChildItem (Split-Path (Get-Command cl).Source) -Filter 'clang_rt.asan_dynamic-aarch64.dll' | Select-Object -First 1
if (-not $runtime) { throw 'no clang_rt.asan_dynamic-aarch64.dll beside cl.exe' }
Copy-Item $runtime.FullName $bin -Force
Set-Content -Path $stamp -Value $commit
"built with AddressSanitizer ($target)"

# the tests, every sanitizer report in a log file of its own
$reports = Join-Path ([IO.Path]::GetTempPath()) 'npp-asan-logs'
New-Item -ItemType Directory -Force $reports | Out-Null
Get-ChildItem $reports -File | ForEach-Object { [IO.File]::Delete($_.FullName) }
$env:ASAN_OPTIONS = "log_path='$reports\asan'"
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'review.ps1') -Path $Worktree -NoBuild -NoFetch -Test ($Test -join ',') -Quiet 2>&1 |
	Where-Object { $_ -match '^\s*FAIL|PASS,' }
Remove-Item Env:ASAN_OPTIONS
$found = @(Get-ChildItem $reports -File)
if ($found.Count -eq 0) { 'PASS  AddressSanitizer: no memory error in the tests' }
else {
	"FAIL  AddressSanitizer: $($found.Count) report(s) in $reports"
	foreach ($f in $found) { "--- $($f.Name)"; Get-Content $f.FullName -TotalCount 30 }
}
