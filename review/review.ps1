#Requires -Version 7
<#
.SYNOPSIS
	Review harness for Pyre909's Notepad++ fork: checks a branch before it is pushed or proposed upstream.
.DESCRIPTION
	Compares a branch (its commits and any uncommitted changes) with its base and reports PASS / WARN / FAIL / INFO:
	branch shape, size, protected areas, line endings and whitespace, coding style (upstream CONTRIBUTING.md),
	localization (english.xml, english_customizable.xml, the texts in the code), MSVC builds and the app-level tests
	in review\tests. Exits with 1 when something failed. The AI part of a review is review\checklist.md (README.md).
.PARAMETER Path
	The worktree (or the clone) to review. Default: the current folder.
.PARAMETER Base
	What the branch is compared with. Default: upstream/master, or origin/pyre when the branch is pyre.
.PARAMETER Build
	MSVC Release builds to make: ARM64, x64, Win32 (default ARM64). -NoBuild skips them.
.PARAMETER Test
	App-level tests to run, by name (file name in review\tests without .ps1), or All. They use the exe of the
	ARM64 build on an ARM64 machine, else the x64 one.
.EXAMPLE
	pwsh -File review.ps1 -Path $HOME\src\npp.worktrees\live-rendering-switch_20261005 -Build ARM64,x64,Win32 -Test All
#>
param(
	[string] $Path = (Get-Location).Path,
	[string] $Base = '',
	[string[]] $Build = @('ARM64'),
	[switch] $NoBuild,
	[string[]] $Test = @(),
	[switch] $NoFetch,
	[switch] $SelfTest
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# "pwsh -File" passes a list as one string ("ARM64,x64"): split it
$Build = @($Build | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Test = @($Test | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$badBuild = @($Build | Where-Object { $_ -notin 'ARM64', 'x64', 'Win32' })
if ($badBuild.Count) { throw "-Build takes ARM64, x64, Win32 (not $($badBuild -join ', '))" }

# ---------------------------------------------------------------------------------------------------------------- output

$script:counts = [ordered]@{ FAIL = 0; WARN = 0; PASS = 0; INFO = 0 }
function Report([ValidateSet('FAIL', 'WARN', 'PASS', 'INFO')] [string] $Level, [string] $Message, [string[]] $Details = @()) {
	$script:counts[$Level]++
	$color = @{ FAIL = 'Red'; WARN = 'Yellow'; PASS = 'Green'; INFO = 'DarkGray' }[$Level]
	Write-Host ('{0,-4}  {1}' -f $Level, $Message) -ForegroundColor $color
	foreach ($d in ($Details | Select-Object -First 15)) { Write-Host "      $d" }
	if ($Details.Count -gt 15) { Write-Host ('      ... {0} more' -f ($Details.Count - 15)) }
}
function Section([string] $Title) { Write-Host ''; Write-Host "== $Title" -ForegroundColor Cyan }

# ------------------------------------------------------------------------------------------------------------------- git

function GitRun([switch] $AllowFail) {
	$script:gitError = ''
	$out = & git -C $script:repo -c core.quotepath=off @args 2>&1 | Where-Object {
		if ($_ -is [Management.Automation.ErrorRecord]) { $script:gitError += "$_ "; $false } else { $true }
	}
	if (($LASTEXITCODE -ne 0) -and -not $AllowFail) { throw "git $($args -join ' ') failed: $script:gitError" }
	$out
}
function G { GitRun @args }
function GTry { GitRun -AllowFail @args }

# ----------------------------------------------------------------------------------------------------------- style rules

# upstream CONTRIBUTING.md's coding style, checked line by line on the added lines (heuristics: no context)
$rules = @(
	@{ Rx = '^ {2,}\S'; Raw = $true; Msg = 'indent with tabs (style 2)' }
	@{ Rx = '^\s*(?:\}\s*)?(?:if|else|for|while|switch|do|try|catch)\b[^{}]*\{\s*$'; Msg = 'brace on its own line (style 1)' }
	@{ Rx = '^[A-Za-z_][^;{}]*\)\s*(?:const\s*)?(?:noexcept\s*)?(?:override\s*)?\{\s*$'; CppOnly = $true; Msg = 'function body brace on its own line (style 1)' }
	@{ Rx = '\b(?:if|for|while|switch|catch)\('; Msg = 'one space between the keyword and its parenthesis (style 6)' }
	@{ Rx = '\b(?!(?:if|for|while|switch|catch|return|sizeof|alignof|decltype|throw|case|new|delete|and|or|not|noexcept|operator|static_assert|L|TEXT)\b)[A-Za-z_]\w*\s+\((?!\*)'; Msg = 'no space between a function name and its parenthesis (style 5)' }
	@{ Rx = '(?<![\w>\])])\((?:const\s+)?(?:unsigned\s+|signed\s+)?(?:int|long|short|char|bool|float|double|size_t|ptrdiff_t|u?intptr_t|DWORD|WORD|BYTE|UINT|INT|LONG|ULONG|HWND|HANDLE|LPARAM|WPARAM|LRESULT|wchar_t|TCHAR|LPC?W?STR|LPC?TSTR)\s*\**\s*\)\s*[\w(&*~-]'; Msg = 'C++ cast instead of a C-style cast (style 12)' }
	@{ Rx = '(?:^|[\s(])(?:not|and|or)\s+[\w(!]'; Msg = 'use !, && and || (style 13)' }
	@{ Rx = '[!=]=\s*L?""|L?""\s*[!=]='; Msg = 'empty() to test a string (style 11)' }
	@{ Rx = '^\s+(?:const\s+)?(?:unsigned\s+)?(?:int|long|short|char|bool|float|double|size_t|u?intptr_t|DWORD|WORD|BYTE|UINT|LONG|HWND|HANDLE|LPARAM|WPARAM|LRESULT|wchar_t|TCHAR)\s+\**\s*[A-Za-z_]\w*\s*;'; Msg = 'initialize variables (style 14)' }
	@{ Rx = '^[A-Za-z_][\w:<>*,\s]*\s[A-Za-z_]\w*::\w+\s*;'; CppOnly = $true; Msg = 'initialize the static member, {} for class types (style 14)' }
	@{ Rx = '\bOutputDebugString|\bprintf\s*\(|std::cout|\bTODO\b|\bFIXME\b'; Raw = $true; Msg = 'debug output or TODO left in' }
	@{ Rx = '[^\x00-\x7F]'; Raw = $true; Msg = 'non-ASCII character in source' }
	@{ Rx = '^\s*using\s+namespace\s+std\s*;'; HOnly = $true; Msg = 'no "using namespace std" in a header' }
)
# code without string/char literals and comments
function Strip-Noise([string] $s) { ($s -replace '"(?:[^"\\]|\\.)*"', '""' -replace "'(?:[^'\\]|\\.)*'", "''" -replace '/\*.*?\*/', '' -replace '//.*$', '') }
function Get-StyleHits([string] $text, [bool] $isCpp) {
	$clean = Strip-Noise $text
	foreach ($r in $rules) {
		if (($r.CppOnly -and -not $isCpp) -or ($r.HOnly -and $isCpp)) { continue }
		if ($(if ($r.Raw) { $text } else { $clean }) -match $r.Rx) { $r.Msg }
	}
}

if ($SelfTest) {
	# each rule must fire on a line that breaks it, and no rule on lines that follow the style
	Section 'Self-test of the style rules'
	$t = "`t"
	$samples = @(
		@{ Code = '    int x = 0;'; Expect = 'indent with tabs' }
		@{ Code = $t + 'if (a) {'; Expect = 'brace on its own line' }
		@{ Code = $t + '} else {'; Expect = 'brace on its own line' }
		@{ Code = 'void Foo::bar() {'; Expect = 'function body brace' }
		@{ Code = $t + 'if(a)'; Expect = 'between the keyword' }
		@{ Code = $t + 'foo (a);'; Expect = 'between a function name' }
		@{ Code = $t + 'int y = (int)x;'; Expect = 'C-style cast' }
		@{ Code = $t + 'if (not a and b)'; Expect = 'use !, && and ||' }
		@{ Code = $t + 'if (s == L"")'; Expect = 'empty()' }
		@{ Code = $t + 'int count;'; Expect = 'initialize variables' }
		@{ Code = 'std::vector<int> Foo::_items;'; Expect = 'initialize the static member' }
		@{ Code = $t + 'OutputDebugString(L"x");'; Expect = 'debug output' }
		@{ Code = $t + '// caf' + [char]0xE9; Expect = 'non-ASCII' }
		@{ Code = 'using namespace std;'; Header = $true; Expect = 'using namespace std' }
		@{ Code = $t + 'if (a)'; Expect = '' }
		@{ Code = $t + 'const auto n = static_cast<int>(x);'; Expect = '' }
		@{ Code = $t + 'std::vector<int> v{};'; Expect = '' }
		@{ Code = $t + 'return (a + b);'; Expect = '' }
		@{ Code = $t + '// if(a) { not a and b, (int)x, foo (a)'; Expect = '' }
		@{ Code = $t + 'auto s = L"if(a) { (int)x";'; Expect = '' }
		@{ Code = $t + 'bool ok = false;'; Expect = '' }
		@{ Code = $t + 'for (size_t i = 0; i < n; ++i)'; Expect = '' }
		@{ Code = $t + $t + 'MB_OK | MB_APPLMODAL);'; Expect = '' }
		@{ Code = '~View() override {'; Header = $true; Expect = '' }
	)
	foreach ($s in $samples) {
		$hits = @(Get-StyleHits $s.Code (-not $s.Header))
		$ok = if ($s.Expect) { ($hits.Count -eq 1) -and ($hits[0] -like "*$($s.Expect)*") } else { $hits.Count -eq 0 }
		Report $(if ($ok) { 'PASS' } else { 'FAIL' }) ('{0,-48} -> {1}' -f $s.Code.Replace($t, '\t'), $(if ($hits.Count) { $hits -join '; ' } else { 'no rule' }))
	}
	Section 'Summary'
	Write-Host ('{0} FAIL, {1} PASS' -f $script:counts.FAIL, $script:counts.PASS)
	exit [int]($script:counts.FAIL -gt 0)
}

$script:repo = (& git -C $Path rev-parse --show-toplevel 2>$null)
if (-not $script:repo) { throw "Not inside a git worktree: $Path" }
$branch = G rev-parse --abbrev-ref HEAD
if (-not $Base) { $Base = if ($branch -eq 'pyre') { 'origin/pyre' } else { 'upstream/master' } }
$toUpstream = $Base -like 'upstream/*'
if (-not $NoFetch) { $remote, $ref = $Base.Split('/', 2); GTry fetch --quiet $remote $ref | Out-Null }
$mb = G merge-base $Base HEAD

Write-Host "Review of $branch in $script:repo" -ForegroundColor Cyan
Write-Host ("Base: {0} (merge base {1}){2}" -f $Base, $mb.Substring(0, 9), $(if ($toUpstream) { ', an upstream pull request' } else { '' }))

# every changed path, committed or not, compared with the merge base
$changes = @(foreach ($l in (G diff --name-status -M $mb)) { $p = $l -split "`t"; [pscustomobject]@{ Status = $p[0].Substring(0, 1); Path = $p[-1] } })
$changed = @($changes | Where-Object Status -ne 'D' | ForEach-Object Path)
$isCode = { param($f) $f -match '\.(cpp|cxx|c|h|hpp|hxx)$' }
$isXml = { param($f) $f -match '\.xml$' }

# added lines of a file with their line numbers in the new version
function Get-AddedLines([string] $file) {
	$n = 0; $inHunk = $false
	foreach ($l in (G diff -U0 --no-color --no-ext-diff $mb -- $file)) {
		if ($l -match '^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@') { $n = [int]$Matches[1]; $inHunk = $true; continue }
		if (-not $inHunk) { continue }
		if ($l.StartsWith('+')) { [pscustomobject]@{ Line = $n; Text = $l.Substring(1).TrimEnd("`r") }; $n++ }
	}
}
function Get-RemovedLines([string] $file) {
	$inHunk = $false
	foreach ($l in (G diff -U0 --no-color --no-ext-diff $mb -- $file)) {
		if ($l.StartsWith('@@')) { $inHunk = $true; continue }
		if ($inHunk -and $l.StartsWith('-')) { $l.Substring(1).TrimEnd("`r") }
	}
}

# ---------------------------------------------------------------------------------------------------------------- branch

Section 'Branch'
$ahead = [int](G rev-list --count "$mb..HEAD"); $behind = [int](G rev-list --count "HEAD..$Base")
$dirty = @(G status --porcelain --untracked-files=no)
$subjects = @(G log --format='%h %s' "$mb..HEAD")
if ($toUpstream) {
	if ($ahead -eq 1) { Report PASS 'one commit on the base (CONTRIBUTING 4: a single commit)' $subjects }
	elseif ($ahead -eq 0) { Report WARN 'nothing committed on the base yet' }
	else { Report WARN "$ahead commits: upstream asks for a single commit (CONTRIBUTING 4)" $subjects }
	if ($branch -match '^[A-Za-z0-9][\w.-]*_\d{8}$') { Report PASS "branch name $branch (<topic>_<YYYYMMDD>, CONTRIBUTING 2)" }
	else { Report WARN "branch name ${branch}: use <topic>_<YYYYMMDD> so it was never used before (CONTRIBUTING 2)" }
	$aiTrailer = @(G log --format='%b' "$mb..HEAD") -match 'Co-Authored-By:.*(Claude|anthropic)'
	if ($aiTrailer) { Report INFO 'AI-assisted commit: say so in the pull request (its template asks)' }
}
else { Report INFO ("{0} commit(s) on {1}" -f $ahead, $Base) $subjects }
if ($behind -gt 0) { Report INFO "$behind commit(s) behind ${Base}: rebase only when needed (CONTRIBUTING 11-12)" }
if ($dirty.Count) { Report WARN "$($dirty.Count) uncommitted change(s), reviewed below but not in the branch yet" ($dirty | ForEach-Object { $_.Trim() }) }

# ------------------------------------------------------------------------------------------------------------------ size

Section 'Size'
$num = @(foreach ($l in (G diff --numstat $mb)) { $p = $l -split "`t"; [pscustomobject]@{ Add = $p[0]; Del = $p[1]; Path = $p[2] } })
$codeAdded = ($num | Where-Object { & $isCode $_.Path } | Where-Object Add -ne '-' | Measure-Object -Property Add -Sum).Sum
$details = @($num | ForEach-Object { '+{0,-4} -{1,-4} {2}' -f $_.Add, $_.Del, $_.Path })
$filesForGuidance = @($num | Where-Object { $_.Path -notmatch 'english_customizable\.xml$' }).Count
if ($toUpstream -and (($filesForGuidance -gt 4) -or ($codeAdded -gt 60))) {
	Report WARN ("{0} files, {1} code lines added: more than upstream's guidance for new contributors (1-4 files, about 30 lines)" -f $num.Count, [int]$codeAdded) $details
}
else { Report INFO ("{0} file(s), {1} code line(s) added" -f $num.Count, [int]$codeAdded) $details }
$untracked = @(G ls-files --others --exclude-standard)
if ($untracked.Count) { Report INFO "$($untracked.Count) untracked file(s), not part of the change unless added" $untracked }

# ------------------------------------------------------------------------------------------------------- protected areas

Section 'Protected areas'
$sci = @($changed | Where-Object { $_ -match '^(scintilla|lexilla)/' })
if ($sci.Count -and $toUpstream) { Report FAIL 'Scintilla/Lexilla code changed: never send Scintilla code upstream (its maintainer refuses LLM-generated code; Notepad++ syncs it from Scintilla releases)' $sci }
elseif ($sci.Count) { Report WARN 'Scintilla/Lexilla code changed: a local patch on pyre, keep it minimal and documented' $sci }
else { Report PASS 'no Scintilla/Lexilla code changed' }

$forkOnly = @($changed | Where-Object { $_ -match '^(\.github/pyre/|\.github/workflows/pyre-|PYRE-BUILD\.md$|CLAUDE\.md$|\.claude/)' })
$pyreText = @(foreach ($f in ($changed | Where-Object { & $isCode $_ })) { Get-AddedLines $f | Where-Object Text -match 'Pyre909' | ForEach-Object { '{0}:{1}: {2}' -f $f, $_.Line, $_.Text.Trim() } })
if ($toUpstream) {
	if ($forkOnly.Count -or $pyreText.Count) { Report FAIL 'fork-only files or "Pyre909" code in an upstream pull request' (@($forkOnly) + @($pyreText)) }
	else { Report PASS 'no fork-only files or code' }
}
if ($changed -contains 'PowerEditor/src/resource.h') {
	$ver = @(Get-AddedLines 'PowerEditor/src/resource.h' | Where-Object Text -match 'VERSION_')
	if ($ver.Count) { Report FAIL 'version line of resource.h changed: upstream edits it each release' ($ver | ForEach-Object { "resource.h:$($_.Line): $($_.Text.Trim())" }) }
}
if (-not $toUpstream) {
	$ci = @($changed | Where-Object { $_ -eq '.github/workflows/CI_build.yml' })
	if ($ci.Count) { Report WARN 'CI_build.yml is upstream''s file: changing it on pyre makes upstream merges conflict' }
}

# ------------------------------------------------------------------------------------------- line endings and whitespace

Section 'Line endings and whitespace'
$eolBad = @()
foreach ($f in $changed) {
	$e = G ls-files --eol -- $f
	if (-not $e) {
		# a new file: compare with the tracked files of its folder
		$dir = Split-Path $f -Parent; $kind = if (Test-Path (Join-Path $script:repo $f)) { if ([IO.File]::ReadAllText((Join-Path $script:repo $f)).Contains("`r`n")) { 'crlf' } else { 'lf' } } else { '' }
		$sib = @(G ls-files --eol -- $(if ($dir) { $dir } else { '.' }) | Select-Object -First 30 | ForEach-Object { if ($_ -match '^i/(\w+)') { $Matches[1] } } | Where-Object { $_ -in 'lf', 'crlf' })
		$main = ($sib | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name
		if ($kind -and $main -and ($kind -ne $main)) { $eolBad += "$f is new with $kind; its folder mostly uses $main" }
		continue
	}
	if ($e -match '^i/(\S+)\s+w/(\S+)') {
		$i = $Matches[1]; $w = $Matches[2]
		if ($w -eq 'mixed') { $eolBad += "$f has mixed line endings" }
		elseif (($i -in 'lf', 'crlf') -and ($w -in 'lf', 'crlf') -and ($i -ne $w)) { $eolBad += "$f converted from $i to $w" }
	}
}
if ($eolBad.Count) { Report FAIL 'line endings changed: keep each file''s own (CRLF for most PowerEditor sources, LF for Scintilla)' $eolBad }
else { Report PASS 'line endings kept' }

$ws = @(GTry -c core.whitespace=cr-at-eol,trailing-space,space-before-tab diff --check $mb | Where-Object { $_ -match '^\S+:\d+:' })
if ($ws.Count) { Report WARN 'whitespace errors' $ws } else { Report PASS 'no whitespace errors' }

# lines in the diff that disappear when whitespace is ignored (tabs shown as →)
$wsOnly = @(foreach ($f in ($changed | Where-Object { & $isCode $_ })) {
	$plain = @(G diff -U0 --no-color $mb -- $f | Where-Object { $_ -match '^[+-](?![+-]{2} )' })
	$noWs = @(G diff -U0 --no-color -w $mb -- $f | Where-Object { $_ -match '^[+-](?![+-]{2} )' })
	if ($plain.Count -ne $noWs.Count) {
		Compare-Object $plain $noWs | Where-Object SideIndicator -eq '<=' | ForEach-Object { '{0}: {1}' -f $f, ($_.InputObject.TrimEnd("`r") -replace "`t", '→') }
	}
})
if ($wsOnly.Count) { Report WARN 'lines changed only in whitespace: fine when the code moved into another block, else leave them as they were (CONTRIBUTING 6-7)' $wsOnly }
else { Report PASS 'no whitespace-only changes' }

# ----------------------------------------------------------------------------------------------------------------- style

Section 'Coding style (added lines, upstream CONTRIBUTING.md)'
$styleHits = [ordered]@{}; $nullHits = @()
foreach ($f in ($changed | Where-Object { & $isCode $_ })) {
	$isCpp = $f -match '\.(cpp|cxx|c)$'
	foreach ($a in (Get-AddedLines $f)) {
		foreach ($msg in (Get-StyleHits $a.Text $isCpp)) {
			if (-not $styleHits.Contains($msg)) { $styleHits[$msg] = @() }
			$styleHits[$msg] += ('{0}:{1}: {2}' -f $f, $a.Line, $a.Text.Trim())
		}
		if ((Strip-Noise $a.Text) -match '\bNULL\b') { $nullHits += ('{0}:{1}: {2}' -f $f, $a.Line, $a.Text.Trim()) }
	}
}
foreach ($k in $styleHits.Keys) { Report WARN $k $styleHits[$k] }
if ($nullHits.Count) { Report INFO 'NULL in new code: nullptr is preferred' $nullHits }
if (-not $styleHits.Count) { Report PASS 'no style rule hit on the added lines (heuristics: still read the diff)' }

# ---------------------------------------------------------------------------------------------------------- localization

Section 'Localization'
foreach ($f in ($changed | Where-Object { & $isXml $_ })) {
	try { [void]([xml](Get-Content -Raw -Encoding UTF8 (Join-Path $script:repo $f))); Report PASS "$f is well-formed" }
	catch { Report FAIL "$f is not well-formed XML" @("$($_.Exception.Message)") }
}
$langDir = 'PowerEditor/installer/nativeLang'; $en = "$langDir/english.xml"; $enc = "$langDir/english_customizable.xml"
if ($changed -contains $en) {
	if ($changed -notcontains $enc) { Report WARN 'english.xml changed but not english_customizable.xml: upstream changes both together' }
	else {
		$d1 = @(Get-AddedLines $en | ForEach-Object { '+' + $_.Text.Trim() }) + @(Get-RemovedLines $en | ForEach-Object { '-' + $_.Trim() })
		$d2 = @(Get-AddedLines $enc | ForEach-Object { '+' + $_.Text.Trim() }) + @(Get-RemovedLines $enc | ForEach-Object { '-' + $_.Trim() })
		$diff = @(Compare-Object $d1 $d2 | ForEach-Object { '{0} {1}' -f $(if ($_.SideIndicator -eq '<=') { 'only english.xml:' } else { 'only customizable:' }), $_.InputObject })
		if ($diff.Count) { Report WARN 'english.xml and english_customizable.xml changed differently' $diff }
		else { Report PASS 'english.xml and english_customizable.xml changed the same way' }
	}
}
$otherLangs = @($changed | Where-Object { ($_ -like "$langDir/*.xml") -and ($_ -notin $en, $enc) })
if ($otherLangs.Count) { Report INFO 'other languages changed: translators usually do it, or a separate [xml] pull request' $otherLangs }

# texts given in the code (messageBox / getLocalizedStrFromID defaults) next to their english.xml entries
$enXml = [xml](Get-Content -Raw -Encoding UTF8 (Join-Path $script:repo $en))
function Unescape-Cpp([string] $s) { $s -replace '\\"', '"' -replace '\\n', "`n" -replace '\\t', "`t" -replace '\\\\', '\' }
$keys = [ordered]@{}
foreach ($f in ($changed | Where-Object { & $isCode $_ })) {
	foreach ($a in (Get-AddedLines $f)) {
		foreach ($m in [regex]::Matches($a.Text, '(?:messageBox|getLocalizedStrFromID)\(\s*"([\w-]+)"')) { $keys[$m.Groups[1].Value] = $f }
	}
	# a changed default text whose call starts on an unchanged line
	foreach ($a in (Get-AddedLines $f)) {
		if ($a.Text -match '^\s*L"') {
			$src = Get-Content (Join-Path $script:repo $f)
			for ($k = $a.Line - 2; $k -ge [Math]::Max(0, $a.Line - 4); $k--) { if ($src[$k] -match '(?:messageBox|getLocalizedStrFromID)\(\s*"([\w-]+)"') { $keys[$Matches[1]] = $f; break } }
		}
	}
}
$textIssues = @(); $missing = @()
foreach ($key in $keys.Keys) {
	$node = $enXml.SelectSingleNode("//$key")
	if (-not $node) { $missing += "$key (used in $($keys[$key]))"; continue }
	$code = Get-Content -Raw (Join-Path $script:repo $keys[$key])
	$mb2 = [regex]::Match($code, 'messageBox\(\s*"' + [regex]::Escape($key) + '"\s*,\s*[^,]+?,\s*L"((?:[^"\\]|\\.)*)"\s*,\s*L"((?:[^"\\]|\\.)*)"')
	$ls = [regex]::Match($code, 'getLocalizedStrFromID\(\s*"' + [regex]::Escape($key) + '"\s*,\s*L"((?:[^"\\]|\\.)*)"')
	if ($mb2.Success) {
		if ((Unescape-Cpp $mb2.Groups[1].Value) -ne $node.message) { $textIssues += "$key message: code `"$(Unescape-Cpp $mb2.Groups[1].Value)`" / english.xml `"$($node.message)`"" }
		if ((Unescape-Cpp $mb2.Groups[2].Value) -ne $node.title) { $textIssues += "$key title: code `"$(Unescape-Cpp $mb2.Groups[2].Value)`" / english.xml `"$($node.title)`"" }
	}
	elseif ($ls.Success -and ((Unescape-Cpp $ls.Groups[1].Value) -ne $node.value)) { $textIssues += "$key`: code `"$(Unescape-Cpp $ls.Groups[1].Value)`" / english.xml `"$($node.value)`"" }
}
if (-not @($changed | Where-Object { & $isXml $_ }).Count -and -not $keys.Count) { Report INFO 'no UI text or XML file changed' }
if ($missing.Count) { Report FAIL 'texts used in the code but missing from english.xml' $missing }
if ($textIssues.Count) { Report WARN 'default texts in the code differ from english.xml (English users without a language file see the code''s)' $textIssues }
elseif ($keys.Count) { Report PASS ("{0} text(s) used in the changed code match english.xml" -f $keys.Count) }

# ----------------------------------------------------------------------------------------------------------------- build

$exe = @{}
$binDir = @{ ARM64 = 'binarm64'; x64 = 'bin64'; Win32 = 'bin' }
if (-not $NoBuild) {
	Section 'Build (MSVC Release)'
	$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
	$all = @(& $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\**\MSBuild.exe')
	$msbuild = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $all | Where-Object { $_ -match '\\arm64\\' } | Select-Object -First 1 } else { $all | Where-Object { $_ -match '\\amd64\\' } | Select-Object -First 1 }
	if (-not $msbuild) { $msbuild = $all | Select-Object -First 1 }
	$logDir = Join-Path ([IO.Path]::GetTempPath()) 'npp-review'; New-Item -ItemType Directory -Force $logDir | Out-Null
	$leaves = @($changed | Where-Object { & $isCode $_ } | ForEach-Object { [regex]::Escape((Split-Path $_ -Leaf)) })
	foreach ($plat in $Build) {
		$log = Join-Path $logDir "build-$($branch -replace '[^\w.-]', '_')-$plat.log"; $start = Get-Date
		& $msbuild (Join-Path $script:repo 'PowerEditor\visual.net\notepadPlus.sln') /m /p:configuration=Release "/p:platform=$plat" /v:quiet /nologo "/flp:logfile=$log;verbosity=normal" | Out-Null
		$code = $LASTEXITCODE; $secs = [int]((Get-Date) - $start).TotalSeconds
		$errors = @(Select-String -Path $log -Pattern ': (fatal )?error ' | ForEach-Object { $_.Line.Trim() } | Select-Object -Unique)
		$warnings = @(if ($leaves.Count) { Select-String -Path $log -Pattern ('(' + ($leaves -join '|') + ')\(\d+.*: warning ') | ForEach-Object { $_.Line.Trim() } | Select-Object -Unique })
		if ($code -ne 0 -or $errors.Count) { Report FAIL "$plat build failed ($secs s, log $log)" $errors }
		else {
			$exe[$plat] = Join-Path $script:repo "PowerEditor\$($binDir[$plat])\notepad++.exe"
			if ($warnings.Count) { Report WARN "$plat build: warnings in the changed files" $warnings } else { Report PASS "$plat build, no warning in the changed files ($secs s)" }
		}
	}
}

# ----------------------------------------------------------------------------------------------------------------- tests

if ($Test.Count) {
	Section 'App-level tests (review\tests)'
	$hostPlat = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'ARM64' } else { 'x64' }
	$testExe = if ($exe[$hostPlat]) { $exe[$hostPlat] } else { Join-Path $script:repo "PowerEditor\$($binDir[$hostPlat])\notepad++.exe" }
	$scripts = @(Get-ChildItem (Join-Path $PSScriptRoot 'tests') -Filter *.ps1 | Where-Object { ($Test -contains 'All') -or ($Test -contains $_.BaseName) })
	if (-not (Test-Path $testExe)) { Report FAIL "no build to test: $testExe" }
	elseif (-not $scripts.Count) { Report WARN "no test named $($Test -join ', ') in $(Join-Path $PSScriptRoot 'tests')" }
	foreach ($s in $scripts) {
		if (-not (Test-Path $testExe)) { break }
		$out = @(& pwsh -NoProfile -File $s.FullName -Exe $testExe 2>&1 | ForEach-Object { "$_" })
		$summary = $out | Where-Object { $_ -match '^(\d+) checks?, (\d+) failed' } | Select-Object -Last 1
		$checks = -1; $failed = -1
		if ($summary -match '^(\d+) checks?, (\d+) failed') { $checks = [int]$Matches[1]; $failed = [int]$Matches[2] }
		# a test that ran no check proves nothing: it skipped this build (for example a pyre test on an upstream branch)
		if ($checks -eq 0) { Report INFO "$($s.BaseName): no check ran, the test skips this build" @($out | Where-Object { $_ -match '^(SKIP|INFO)\b' }) }
		elseif (($checks -gt 0) -and ($failed -eq 0)) { Report PASS "$($s.BaseName): $summary" }
		else { Report FAIL "$($s.BaseName): $(if ($summary) { $summary } else { 'no summary line' })" @($out | Where-Object { $_ -match '^FAIL\b|Exception|\berror\b' }) }
	}
}

# --------------------------------------------------------------------------------------------------------------- summary

Section 'Summary'
Write-Host ('{0} FAIL, {1} WARN, {2} PASS, {3} INFO' -f $script:counts.FAIL, $script:counts.WARN, $script:counts.PASS, $script:counts.INFO) -ForegroundColor $(if ($script:counts.FAIL) { 'Red' } elseif ($script:counts.WARN) { 'Yellow' } else { 'Green' })
Write-Host 'Fix every FAIL; fix or explain every WARN. Then the AI review: review\checklist.md (skill npp-review).'
exit [int]($script:counts.FAIL -gt 0)
