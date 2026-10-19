# Measures Scintilla's layout cache (SCI_SETLAYOUTCACHE) and layout threads (SCI_SETLAYOUTTHREADS) in Notepad++ builds
# (2026-10-19, see STATUS.md). Each configuration ("cache/threads", e.g. 2/6) runs in fresh processes (median of
# -Rounds); the options are sent to the views' Scintilla windows after startup, before any measurement. Tab 1: a
# 1,000,000-line file (~60 MB); tab 2: 20 lines of ~250 KB (JSON). With several -Exe (and -Names), the builds alternate
# inside each round: the VM's speed drifts between runs. The settings folder is %TEMP%\npp-layout-perf-settings-<Label>:
# put a stylers.xml there for another Default Style font (a proportional one makes the measuring cost show). Compare
# copies of the builds in plain folders: a build path UMDH records stacks for (review\umdh-scope.ps1) runs slower.
param([Parameter(Mandatory)] [string[]] $Exe, [string[]] $Names = @('build'), [string] $Label = 'build', [int] $Rounds = 3,
	[string[]] $Configs = @('1/1', '2/1', '3/1', '1/6', '2/6', '3/6'), [string] $Out)
$ErrorActionPreference = 'Stop'
Add-Type -Namespace LP -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool InvalidateRect(IntPtr h, IntPtr r, bool erase);
[DllImport("user32.dll")] public static extern bool UpdateWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
'@
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][LP.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 0, 600000, [ref]$r); $r.ToInt64() }
function Paint([IntPtr] $h) { [void][LP.U]::InvalidateRect($h, [IntPtr]::Zero, $false); [void][LP.U]::UpdateWindow($h) }
function Time([scriptblock] $b) { $sw = [Diagnostics.Stopwatch]::StartNew(); & $b; $sw.Elapsed.TotalMilliseconds }

$data = Join-Path $env:TEMP 'npp-layout-perf'; if (-not (Test-Path $data)) { New-Item -ItemType Directory $data | Out-Null }
$big = Join-Path $data 'big.cpp'; $long = Join-Path $data 'long.json'
if (-not (Test-Path $big)) { [IO.File]::WriteAllLines($big, [string[]](1..1000000 | ForEach-Object { "int value_$_ = compute($_, ""text $_""); // line $_ of the large file" })) }
if (-not (Test-Path $long)) {
	$lines = foreach ($l in 1..20) { $sb = [Text.StringBuilder]::new(); foreach ($i in 1..4000) { [void]$sb.Append("{""id"":$i,""name"":""item $l-$i"",""tags"":[""alpha"",""beta""],""value"":$i.5},") }; $sb.ToString() }
	[IO.File]::WriteAllLines($long, [string[]]$lines)
}

$SCI = @{ GETLINECOUNT = 2154; ENSUREVISIBLE = 2232; SETWRAPMODE = 2268; SETLAYOUTCACHE = 2272; GETLAYOUTCACHE = 2273
	SETLAYOUTTHREADS = 2775; GETLAYOUTTHREADS = 2776; SETZOOM = 2373; CHARRIGHT = 2306; LINESCROLL = 2168
	SETFIRSTVISIBLELINE = 2613; GOTOPOS = 2025; GOTOLINE = 2024; POSITIONFROMLINE = 2167; GETTECHNOLOGY = 2631 }

function Measure-Config([string] $exePath, [string] $name, [string] $config, [int] $round) {
	$cache, $threads = $config -split '/'
	$dir = Join-Path $env:TEMP "npp-layout-perf-settings-$Label"; if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
	$sw = [Diagnostics.Stopwatch]::StartNew()
	$p = Start-Process $exePath -ArgumentList '-multiInst', '-nosession', "-settingsDir=$dir", $big, $long -PassThru
	try {
		while ($p.MainWindowHandle -eq 0) { Start-Sleep -Milliseconds 20; $p.Refresh() }
		$main = $p.MainWindowHandle; [void](Send $main 0); $startup = $sw.Elapsed.TotalMilliseconds; Start-Sleep -Milliseconds 1500
		$views = @(); $h = [IntPtr]::Zero
		while (($h = [LP.U]::FindWindowEx($main, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { $views += $h }
		foreach ($v in $views) { [void](Send $v $SCI.SETLAYOUTCACHE $cache); [void](Send $v $SCI.SETLAYOUTTHREADS $threads) }
		$sc = $views | Where-Object { [LP.U]::IsWindowVisible($_) } | Select-Object -First 1
		$r = [ordered]@{ config = "$config $name"; round = $round; technology = Send $sc $SCI.GETTECHNOLOGY; cache = Send $sc $SCI.GETLAYOUTCACHE; threads = Send $sc $SCI.GETLAYOUTTHREADS; 'startup with both files, ms' = $startup }

		# Tab 2, the long lines (active at startup)
		[void](Send $main 0x111 44087); Paint $sc
		$r['long: relayout (zoom), ms'] = (Time { foreach ($i in 1..5) { [void](Send $sc $SCI.SETZOOM 1); Paint $sc; [void](Send $sc $SCI.SETZOOM 0); Paint $sc } }) / 10
		$r['long: repaint, ms'] = (Time { foreach ($i in 1..30) { Paint $sc } }) / 30
		[void](Send $sc $SCI.GOTOPOS ((Send $sc $SCI.POSITIONFROMLINE 9) + 100000)); Paint $sc
		$r['long: caret move, ms'] = (Time { foreach ($i in 1..50) { [void](Send $sc $SCI.CHARRIGHT); Paint $sc } }) / 50
		$r['long: tab switch, ms'] = (Time { foreach ($i in 1..5) { [void](Send $main 0x111 44086); Paint $sc; [void](Send $main 0x111 44087); Paint $sc } }) / 10
		$r['long: wrap on, ms'] = Time { [void](Send $sc $SCI.SETWRAPMODE 1); [void](Send $sc $SCI.ENSUREVISIBLE ((Send $sc $SCI.GETLINECOUNT) - 1)); Paint $sc }
		$r['long: wrapped scroll, ms'] = (Time { foreach ($i in 0..19) { [void](Send $sc $SCI.SETFIRSTVISIBLELINE ($i * 40)); Paint $sc } }) / 20
		[void](Send $sc $SCI.GOTOPOS ((Send $sc $SCI.POSITIONFROMLINE 9) + 100000)); Paint $sc
		$r['long: typing (wrapped), ms'] = (Time { foreach ($i in 1..20) { [void](Send $sc 0x0102 0x20); Paint $sc } }) / 20
		[void](Send $sc $SCI.SETWRAPMODE 0); Paint $sc
		[void](Send $sc $SCI.GOTOPOS ((Send $sc $SCI.POSITIONFROMLINE 11) + 100000)); Paint $sc
		$r['long: typing, ms'] = (Time { foreach ($i in 1..20) { [void](Send $sc 0x0102 0x20); Paint $sc } }) / 20

		# Tab 1, the 1,000,000 lines
		[void](Send $main 0x111 44086); Paint $sc
		[void](Send $sc $SCI.GOTOLINE 500000); Paint $sc
		$r['big: repaint, ms'] = (Time { foreach ($i in 1..100) { Paint $sc } }) / 100
		$r['big: line scroll, ms'] = (Time { foreach ($i in 1..200) { [void](Send $sc $SCI.LINESCROLL 0 1); Paint $sc } }) / 200
		$r['big: jump scroll, ms'] = (Time { foreach ($i in 0..99) { [void](Send $sc $SCI.SETFIRSTVISIBLELINE ($i * 9000)); Paint $sc } }) / 100
		$r['big: wrap on, ms'] = Time { [void](Send $sc $SCI.SETWRAPMODE 1); [void](Send $sc $SCI.ENSUREVISIBLE ((Send $sc $SCI.GETLINECOUNT) - 1)); Paint $sc }
		$r['big: wrapped jump scroll, ms'] = (Time { foreach ($i in 0..99) { [void](Send $sc $SCI.SETFIRSTVISIBLELINE ($i * 9000)); Paint $sc } }) / 100
		[void](Send $sc $SCI.GOTOLINE 500000); Paint $sc
		$r['big: typing (wrapped), ms'] = (Time { foreach ($i in 1..50) { [void](Send $sc 0x0102 0x20); Paint $sc } }) / 50
		$p.Refresh(); $r['private memory, MB'] = [math]::Round($p.PrivateMemorySize64 / 1MB)
		[pscustomobject]$r
	}
	finally { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(10000) } }
}

# builds alternated inside each round, so that a drift of the machine's speed hits them alike
$all = foreach ($round in 1..$Rounds) { foreach ($c in $Configs) { for ($b = 0; $b -lt $Exe.Count; $b++) { Measure-Config $Exe[$b] $Names[$b] $c $round } } }
$cols = foreach ($c in $Configs) { foreach ($n in $Names) { "$c $n" } }
if ($Out) { $all | Export-Csv -NoTypeInformation $Out }
$keys = $all[0].PSObject.Properties.Name | Where-Object { $_ -notin 'config', 'round' }
"== $Label (median of $Rounds; config = layout cache / threads; cache 1 = caret (default), 2 = page, 3 = document)"
$hdr = '{0,-30}' -f 'measure'; foreach ($c in $cols) { $hdr += '{0,12}' -f $c }; $hdr
foreach ($k in $keys) {
	$line = '{0,-30}' -f $k
	foreach ($c in $cols) { $v = @($all | Where-Object config -eq $c | ForEach-Object { [double]$_.$k } | Sort-Object); $line += '{0,12}' -f [math]::Round($v[[int][math]::Floor($v.Count / 2)], 1) }
	$line
}
