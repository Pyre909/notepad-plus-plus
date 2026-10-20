# Profile-guided optimization of a Release notepad++.exe: the steps of the Pyre909 release (pyre-release.yml), also run
# by hand (PowerShell 7, from any folder):
#   pgo.ps1 -Step Instrument -Platform x64|ARM64
#       Release built with /p:PyrePgo=Instrument (notepadPlus.Cpp.props), the instrumented exe made ready to train:
#       pgort140.dll of the platform, functionList and autoCompletion (from PowerEditor/installer) next to it.
#   pgo.ps1 -Step Train [-Exe <instrumented notepad++.exe>] [-Passes <n>]
#       bench.ps1 -Train run n times: each closes Notepad++ normally, which writes notepad++!N.pgc next to the exe.
#   pgo.ps1 -Step Optimize -Platform x64|ARM64
#       Release built with /p:PyrePgo=Optimize: notepad++.pgd and the .pgc files in the output folder; fails when under
#       -MinProfiled % of the functions used the profile (a profile of other code). A fresh checkout can optimize with a
#       profile trained elsewhere: an identical compile matches it (100.0% on 2026-10-20).
param(
	[Parameter(Mandatory)] [ValidateSet('Instrument', 'Train', 'Optimize')] [string] $Step,
	[ValidateSet('x64', 'ARM64')] [string] $Platform = 'x64',
	[string] $Exe = '',
	[int] $Passes = 1,
	[double] $MinProfiled = 95
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$out = Join-Path $root ('PowerEditor\' + @{ x64 = 'bin64'; ARM64 = 'binarm64' }[$Platform])
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

function Get-MSBuild {
	$cmd = Get-Command msbuild -ErrorAction SilentlyContinue
	if ($cmd) { return $cmd.Source }
	$all = @(& $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\**\MSBuild.exe')
	$native = $all | Where-Object { $_ -match $(if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { '\\arm64\\' } else { '\\amd64\\' }) } | Select-Object -First 1
	if ($native) { $native } else { $all | Select-Object -First 1 }
}
function Build([string] $pgo) {
	$log = Join-Path $env:TEMP "pyre-pgo-$Platform-$pgo.log"
	# its output shown, not returned: the function returns the log's path only
	& (Get-MSBuild) (Join-Path $root 'PowerEditor\visual.net\notepadPlus.sln') /m /p:configuration=Release "/p:platform=$Platform" "/p:PyrePgo=$pgo" /nologo /v:minimal "/flp:logfile=$log;verbosity=normal" | Out-Host
	if ($LASTEXITCODE -ne 0) { throw "the $pgo build failed (exit $LASTEXITCODE)" }
	$log
}
# the platform's file of that name under a folder (by the machine of its PE header: the toolset has one per host and target)
function Find-PlatformFile([string] $dir, [string] $name) {
	$machine = @{ x64 = 0x8664; ARM64 = 0xAA64 }[$Platform]
	Get-ChildItem $dir -Recurse -Filter $name -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\onecore\\' } | Where-Object {
		$header = [byte[]]::new(4096)
		$fs = [IO.File]::OpenRead($_.FullName); try { [void]$fs.Read($header, 0, $header.Length) } finally { $fs.Dispose() }
		$pe = [BitConverter]::ToInt32($header, 0x3C)
		($pe -gt 0) -and ($pe -lt 4090) -and ([BitConverter]::ToUInt16($header, $pe + 4) -eq $machine)
	} | Select-Object -First 1
}

switch ($Step) {
	'Instrument' {
		Get-ChildItem $out -Filter '*.pgc' -ErrorAction SilentlyContinue | Remove-Item -Force
		[void](Build 'Instrument')
		$vs = & $vswhere -latest -products * -property installationPath
		# of the newest toolset, the one the build used (a runner can have older ones side by side, 14.29 of VS 2019)
		$pgort = Get-ChildItem (Join-Path $vs 'VC\Tools\MSVC') -Directory | Sort-Object { [version]$_.Name } -Descending |
			ForEach-Object { Find-PlatformFile $_.FullName 'pgort140.dll' } | Select-Object -First 1
		if (-not $pgort) { throw "no $Platform pgort140.dll under $vs\VC\Tools\MSVC" }
		Copy-Item $pgort.FullName $out -Force
		foreach ($d in @(@('functionList', 'functionList'), @('APIs', 'autoCompletion'))) {
			$dest = Join-Path $out $d[1]
			if (Test-Path $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
			Copy-Item -Recurse (Join-Path $root "PowerEditor\installer\$($d[0])") $dest
		}
		"instrumented: $(Join-Path $out 'notepad++.exe'), with $($pgort.FullName)"
	}
	'Train' {
		if (-not $Exe) { $Exe = Join-Path $out 'notepad++.exe' }
		foreach ($pass in 1..$Passes) {
			$sw = [Diagnostics.Stopwatch]::StartNew()
			& (Join-Path $PSScriptRoot 'bench.ps1') -Exe $Exe -Names "training$pass" -Train
			"training pass $pass took $([int]$sw.Elapsed.TotalSeconds) s"
		}
		$pgc = @(Get-ChildItem (Split-Path $Exe) -Filter '*.pgc')
		if (-not $pgc.Count) { throw 'the training wrote no profile (.pgc): Notepad++ has to close normally' }
		"profile: $(($pgc | ForEach-Object Name) -join ', ')"
	}
	'Optimize' {
		if (-not (Test-Path (Join-Path $out 'notepad++.pgd'))) { throw "no notepad++.pgd in $out" }
		if (-not (Get-ChildItem $out -Filter '*.pgc')) { throw "no .pgc in $out" }
		$log = Build 'Optimize'
		$used = Select-String -Path $log -Pattern '\d+ of \d+ functions \(\s*([\d.]+)%\) were optimized using profile data' | Select-Object -Last 1
		if (-not $used) { throw 'the optimized link reported no use of the profile' }
		"profile use: $($used.Line.Trim())"
		$pct = [double]$used.Matches[0].Groups[1].Value
		if ($pct -lt $MinProfiled) { throw "only $pct% of the functions used the profile (minimum $MinProfiled%): a profile of other code?" }
	}
}
