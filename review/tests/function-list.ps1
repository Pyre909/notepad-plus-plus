# App-level test (review harness): upstream's Function List unit tests (PowerEditor\Test\FunctionList: each language's
# unitTest file parsed with -export=functionList, the JSON compared with unitTest.expected.result), run with the build
# under review, from a copy in a folder of its own (the parsers of PowerEditor\installer\functionList and the two test
# files of filesForTesting next to it, a settings folder of its own, the tests copied: nothing written in the tree).
# Each parse is timed: the Function List's speed (its regexes, 2026-10-20). Upstream's CI runs them in its Win32 Debug job.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [string] $PowerEditor = '', [string[]] $Only = @())
$ErrorActionPreference = 'Stop'
if (-not $PowerEditor) { $PowerEditor = Split-Path (Split-Path $Exe) }	# <repo>\PowerEditor\bin*\notepad++.exe
$tests = Join-Path $PowerEditor 'Test\FunctionList'
if (-not (Test-Path (Join-Path $tests 'cpp\unitTest'))) { "INFO  no Function List unit tests under $PowerEditor (a build tree's exe is needed): skipped"; '0 checks, 0 failed'; exit }

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\function-list-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$app = Join-Path $root 'app'; $settings = Join-Path $root 'settings'; $work = Join-Path $root 'tests'
New-Item -ItemType Directory -Force $app, $settings | Out-Null
Copy-Item $Exe $app
foreach ($model in 'langs.model.xml', 'stylers.model.xml') {
	$src = @((Join-Path (Split-Path $Exe) $model), (Join-Path $PowerEditor "src\$model")) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
	Copy-Item $src $app
}
Copy-Item -Recurse (Join-Path $PowerEditor 'installer\functionList') (Join-Path $app 'functionList')
foreach ($f in 'regexGlobalTest.xml', 'overrideMap.xml') { Copy-Item (Join-Path $PowerEditor "installer\filesForTesting\$f") (Join-Path $app 'functionList') -Force }
Copy-Item -Recurse $tests $work
# the unitTest files with CRLF line endings, as a checkout of upstream's CI has them (Git for Windows' core.autocrlf true):
# the expected results were made so (bash's first function is missed with LF); this tree's clone keeps LF (autocrlf false)
foreach ($u in Get-ChildItem $work -Recurse -File | Where-Object { $_.Name -ieq 'unitTest' }) {
	$bytes = [IO.File]::ReadAllBytes($u.FullName)	# bytes, whatever the file's encoding: a lone LF becomes CR LF
	$out = [Collections.Generic.List[byte]]::new($bytes.Length + 1024)
	for ($i = 0; $i -lt $bytes.Length; $i++) {
		if (($bytes[$i] -eq 10) -and (($i -eq 0) -or ($bytes[$i - 1] -ne 13))) { $out.Add(13) }
		$out.Add($bytes[$i])
	}
	[IO.File]::WriteAllBytes($u.FullName, $out.ToArray())
}
$appExe = Join-Path $app (Split-Path $Exe -Leaf)

$results = [Collections.Generic.List[string]]::new(); $fails = 0; $total = [Diagnostics.Stopwatch]::new()
# every folder with a unitTest file: its language is its top folder's name (udl-<name>: a user defined language)
$cases = Get-ChildItem $work -Recurse -File | Where-Object { ($_.Name -ieq 'unitTest') -and ((-not $Only.Count) -or ($_.DirectoryName.Substring($work.Length + 1).Split('\')[0] -in $Only)) } | Sort-Object FullName
foreach ($case in $cases) {
	$rel = $case.DirectoryName.Substring($work.Length + 1)
	$lang = ($rel -split '\\')[0]
	$langArg = if ($lang.StartsWith('udl-')) { '-udl=' + $lang.Substring(4) } else { "-l$lang" }
	$resultFile = Join-Path $case.DirectoryName 'unitTest.result.json'
	$sw = [Diagnostics.Stopwatch]::StartNew(); $total.Start()
	$p = Start-Process $appExe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-export=functionList', $langArg, "`"$($case.FullName)`"" -PassThru
	$exited = $p.WaitForExit(600000)
	$total.Stop()
	$ms = $sw.Elapsed.TotalMilliseconds
	if (-not $exited) { Stop-Process -Id $p.Id -Force; $fails++; $results.Add("FAIL  $rel ($langArg): no result in 10 minutes"); continue }
	$expected = Join-Path $case.DirectoryName 'unitTest.expected.result'
	# as upstream's unitTest.ps1: the results compared with their CRLF written as LF
	$ok = (Test-Path $resultFile) -and (([IO.File]::ReadAllText($resultFile).Replace('\r\n', '\n').TrimEnd()) -eq ([IO.File]::ReadAllText($expected).Replace('\r\n', '\n').TrimEnd()))
	if (-not $ok) { $fails++ }
	$results.Add(("{0}  {1} ({2}): {3:N0} ms, {4:N0} KB" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $rel, $langArg, $ms, ($case.Length / 1KB)))
}
$results
"INFO  all the parses: {0:N1} s" -f $total.Elapsed.TotalSeconds
"work folder: $root"
"{0} checks, {1} failed" -f $results.Count, $fails
