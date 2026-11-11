# App-level test (review harness), Pyre909 builds only: Windows' setting broadcasts (WM_SETTINGCHANGE) forwarded to the
# Scintilla views only when they may concern them (2026-11-10: each restyles and re-wraps a whole document). A C++ file of
# 60,000 lines wrapped and the Document Map shown: Notepad++'s CPU over the 3 s after each broadcast, less an idle 3 s.
# Broadcasts of areas Scintilla never reads ("Policy", "Environment", "intl"): next to nothing. Settings Scintilla reads
# (SPI_SETMOUSEVANISH and SPI_SETCURSORS, read by its GetMouseParameters; SPI_SETWHEELSCROLLLINES), a theme change
# ("immersivecolorset", case aside) and an unnamed one: forwarded, the documents re-wrapped (much CPU).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace SCH -Name U -MemberDefinition @'
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-setting-change-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $root | Out-Null
$file = Join-Path $root 'big.cpp'
$sb = [Text.StringBuilder]::new(5000000)
foreach ($i in 1..60000) { [void]$sb.Append("static int f$i(int a, const char* s) { return a * $i + (s ? 1 : 0); } /* block $i, then a few more words */`r`n") }
[IO.File]::WriteAllText($file, $sb.ToString())
$settings = Join-Path $root 'settings'; New-Item -ItemType Directory -Force $settings | Out-Null
$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', "`"$file`"" -PassThru
try {
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	$m = $p.MainWindowHandle; $r = [IntPtr]::Zero
	[void][SCH.U]::SendMessageTimeout($m, 0x0111, [IntPtr]44022, [IntPtr]::Zero, 2, 30000, [ref]$r) # word wrap
	[void][SCH.U]::SendMessageTimeout($m, 0x0111, [IntPtr]44080, [IntPtr]::Zero, 2, 30000, [ref]$r) # Document Map
	Start-Sleep -Seconds 6
	function Cpu { $p.Refresh(); $p.TotalProcessorTime.TotalMilliseconds }
	$c0 = Cpu; Start-Sleep -Seconds 3; $idle = (Cpu) - $c0
	# the CPU after a WM_SETTINGCHANGE (wParam, lParam: an area's name or none)
	function Cost([long] $wParam, [string] $area) {
		$c0 = Cpu
		if ($area) { [void][SCH.U]::SendMessageTimeout($m, 0x001A, [IntPtr]$wParam, $area, 2, 30000, [ref]$r) }
		else { [void][SCH.U]::SendMessageTimeout($m, 0x001A, [IntPtr]$wParam, [IntPtr]::Zero, 2, 30000, [ref]$r) }
		Start-Sleep -Seconds 3
		[Math]::Round((Cpu) - $c0 - $idle)
	}
	$ignored = @(foreach ($area in 'Policy', 'Environment', 'intl') { Cost 0 $area })
	$forwarded = @((Cost 0x1021 ''), (Cost 0x0057 ''), (Cost 0x0069 ''), (Cost 0 'immersivecolorset'), (Cost 0 ''))
	Check 'broadcasts of areas Scintilla never reads ("Policy", "Environment", "intl"): not forwarded, next to no CPU' (@($ignored | Where-Object { $_ -gt 150 }).Count -eq 0) "ms of CPU: $($ignored -join ', ') (idle 3 s: $([Math]::Round($idle)) ms)"
	Check 'settings Scintilla reads (pointer hiding, cursors, wheel lines), a theme change, an unnamed one: forwarded, the documents re-wrapped' (@($forwarded | Where-Object { $_ -lt 250 }).Count -eq 0) "ms of CPU: $($forwarded -join ', ')"
}
finally {
	if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
	$script:results
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
