# Times Replace All in layout-perf.ps1's 1,000,000-line file (run that first), each in a fresh process (median of
# -Rounds), through the real Replace dialog. -Modes: plain, and noredraw (the view's redraw turned off around it from
# outside, WM_SETREDRAW FALSE/TRUE, what the fix of upstream #10301 does inside). -Extended for escapes in -Find and
# -Replace (';\r\n// line' adds a line per match); -Pre 'msg:wParam,...' sends Scintilla messages to every view first.
# 2026-10-19: adding a line per match took 169 s as Notepad++ was, 3.3 s with the redraw off.
param([Parameter(Mandatory)] [string] $Exe, [string] $Label = 'build', [int] $Rounds = 3, [string[]] $Modes = @('plain', 'noredraw'),
	[string] $Find = 'value_', [string] $Replace = 'v_', [switch] $Extended, [string] $Pre = '')
$ErrorActionPreference = 'Stop'
Add-Type -Namespace RP -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr SendMessageStr(IntPtr h, uint m, IntPtr w, string l);
[DllImport("user32.dll")] public static extern bool InvalidateRect(IntPtr h, IntPtr r, bool erase);
[DllImport("user32.dll")] public static extern bool UpdateWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
'@
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][RP.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 0, 600000, [ref]$r); $r.ToInt64() }
$big = Join-Path $env:TEMP 'npp-layout-perf\big.cpp'
$rows = foreach ($round in 1..$Rounds) { foreach ($mode in $Modes) {
	$dir = Join-Path $env:TEMP "npp-replace-perf-$Label"; if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$dir", $big -PassThru
	try {
		while ($p.MainWindowHandle -eq 0) { Start-Sleep -Milliseconds 20; $p.Refresh() }
		$main = $p.MainWindowHandle; [void](Send $main 0); Start-Sleep -Milliseconds 1500
		$sc = [IntPtr]::Zero; do { $sc = [RP.U]::FindWindowEx($main, $sc, 'Scintilla', [NullString]::Value) } until (($sc -eq [IntPtr]::Zero) -or [RP.U]::IsWindowVisible($sc))
		[void](Send $sc 2025 0)	# SCI_GOTOPOS 0
		foreach ($m in ($Pre -split ',' | Where-Object { $_ })) { $mw = $m -split ':'; $hh = [IntPtr]::Zero; while (($hh = [RP.U]::FindWindowEx($main, $hh, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { [void](Send $hh ([int]$mw[0]) ([int]$mw[1])) } }	# messages sent to every view first (msg:wParam,...)
		$before = Send $sc 2006	# SCI_GETLENGTH
		[void](Send $main 0x111 43003)	# IDM_SEARCH_REPLACE
		$dlg = [IntPtr]::Zero
		for ($t = 0; $t -lt 200 -and $dlg -eq [IntPtr]::Zero; $t++) {
			$h = [IntPtr]::Zero
			while (($h = [RP.U]::FindWindowEx([IntPtr]::Zero, $h, '#32770', 'Replace')) -ne [IntPtr]::Zero) { $q = 0; [void][RP.U]::GetWindowThreadProcessId($h, [ref]$q); if ($q -eq $p.Id) { $dlg = $h; break } }
			if ($dlg -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 20 }
		}
		if ($dlg -eq [IntPtr]::Zero) { throw 'no Replace dialog' }
		[void][RP.U]::SendMessageStr([RP.U]::GetDlgItem($dlg, 1601), 0x000C, [IntPtr]::Zero, $Find)	# IDFINDWHAT, WM_SETTEXT
		[void][RP.U]::SendMessageStr([RP.U]::GetDlgItem($dlg, 1602), 0x000C, [IntPtr]::Zero, $Replace)	# IDREPLACEWITH
		if ($Extended) { [void](Send ([RP.U]::GetDlgItem($dlg, 1625)) 0x00F1 0); [void](Send ([RP.U]::GetDlgItem($dlg, 1626)) 0x00F1 1); [void](Send $dlg 0x111 1626 ([RP.U]::GetDlgItem($dlg, 1626)).ToInt64()) }	# IDNORMAL off, IDEXTENDED on
		$sw = [Diagnostics.Stopwatch]::StartNew()
		if ($mode -eq 'noredraw') { [void](Send $sc 0x000B 0) }	# WM_SETREDRAW FALSE
		[void](Send $dlg 0x111 1609 ([RP.U]::GetDlgItem($dlg, 1609)).ToInt64())	# WM_COMMAND IDREPLACEALL
		if ($mode -eq 'noredraw') { [void](Send $sc 0x000B 1); [void][RP.U]::InvalidateRect($sc, [IntPtr]::Zero, $true) }	# WM_SETREDRAW TRUE
		[void][RP.U]::UpdateWindow($sc)
		$ms = $sw.Elapsed.TotalMilliseconds
		$after = Send $sc 2006
		[pscustomobject]@{ mode = $mode; round = $round; ms = [math]::Round($ms); lines = Send $sc 2154; length = $after - $before }
	}
	finally { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(10000) } }
} }
$rows | Format-Table -AutoSize | Out-String
foreach ($m in $Modes) { $v = @($rows | Where-Object mode -eq $m | ForEach-Object ms | Sort-Object); "== $Label $m : median $($v[[int][math]::Floor($v.Count / 2)]) ms" }
