# App-level test (review harness): no resource leak in what the fork's changes do over and over. Each operation runs 300
# times after a warm-up, and the process's GDI objects, USER objects, kernel handles and private memory are compared
# before and after; a leak grows with the count. Operations: right-to-left and back (rtl-views-gdi: the technology
# switches), Windows setting changes (directwrite-font-smoothing: WM_SETTINGCHANGE), tab switches between a C++ and a
# Python file with a font of a weight as the Default Style font (directwrite-font-names: each switch styles the view
# again), the rendering mode switched through every mode (live-rendering-switch; skipped if the build has no live switch),
# Pyre909's font ligatures and line spacing turned off and on with DirectWrite (each turn realises the fonts again, with
# or without their DirectWrite typography; skipped if the build has no such option).
# Any build runs every operation; what a build doesn't have costs nothing, so its growth is the baseline.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [int] $Count = 300)
$ErrorActionPreference = 'Stop'
Add-Type -Namespace LK -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr hProcess, uint flags);
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $WM_SETTINGCHANGE = 0x001A; $SPI_SETFONTSMOOTHING = 0x004B
$CB_SETCURSEL = 0x014E; $IDC_COMBO_SC_TECHNOLOGY_CHOICE = 6362; $SELCHANGE = [IntPtr]((1 -shl 16) -bor 6362)
$IDM_SETTING_PREFERENCE = 48011; $IDM_EDIT_RTL = 42026; $IDM_EDIT_LTR = 42027; $IDM_VIEW_TAB1 = 44086; $IDM_VIEW_TAB2 = 44087
$BM_SETCHECK = 0x00F1; $IDC_COMBO_LINESPACING = 6288; $IDC_CHECK_FONTLIGATURES = 6289

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][LK.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][LK.U]::GetWindowText($h, $sb, 256); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][LK.U]::EnumWindows({ param($h, $l) $p = 0; [void][LK.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][LK.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Send-Sync([IntPtr] $h, [int] $msg, [IntPtr] $w, [IntPtr] $l) { $r = [IntPtr]::Zero; [void][LK.U]::SendMessageTimeout($h, $msg, $w, $l, 2, 5000, [ref]$r); $r }
function Invoke-Cmd([int] $id) { [void](Send-Sync $script:main $WM_COMMAND ([IntPtr]$id) ([IntPtr]::Zero)) }

# the counters, after the queued messages are handled (a round trip through the message loop) and a collection pass
function Get-Counters {
	[void](Send-Sync $script:main 0 ([IntPtr]::Zero) ([IntPtr]::Zero)); Start-Sleep -Milliseconds 300
	$script:proc.Refresh()
	[pscustomobject]@{
		Gdi = [LK.U]::GetGuiResources($script:proc.Handle, 0); User = [LK.U]::GetGuiResources($script:proc.Handle, 1)
		Handles = $script:proc.HandleCount; PrivateMB = [math]::Round($script:proc.PrivateMemorySize64 / 1MB, 1)
	}
}
# UMDH (Debugging Tools for Windows), where the build records allocation stacks (umdh-scope.ps1): a heap snapshot
# before and after each operation's repetitions, the growth with the stack that allocated it
$script:umdh = 'C:\Program Files (x86)\Windows Kits\10\Debuggers\arm64\umdh.exe'
$script:useUmdh = (Test-Path $script:umdh) -and -not $env:ASAN_OPTIONS
function Save-Heap([string] $file) { & $script:umdh "-p:$($script:proc.Id)" "-f:$file" 2>&1 | Out-String }
# the growth between two snapshots: total bytes, and the largest entries with their stacks (Notepad++'s frames first)
function Get-HeapGrowth([string] $before, [string] $after, [string] $diff) {
	& $script:umdh -d $before $after "-f:$diff" 2>&1 | Out-Null
	$text = Get-Content $diff
	$total = 0
	foreach ($l in $text) { if ($l -match '^Total increase ==\s+(\d+) requested') { $total = [long]$Matches[1] } }
	$entries = [Collections.Generic.List[string]]::new(); $current = $null
	foreach ($l in $text) {
		if (($l -match '^\+\s+[0-9A-F]+ \(') -and ($l -notmatch 'allocations$')) { if ($current) { $entries.Add($current) }; $current = $l.Trim() }
		elseif ($current -and ($l -match '^\s+\S+!\S+')) { if (($current -split ' <- ').Count -lt 6) { $current += ' <- ' + $l.Trim() } }
		elseif ($current -and -not $l.Trim()) { $entries.Add($current); $current = $null }
	}
	if ($current) { $entries.Add($current) }
	[pscustomobject]@{ Bytes = $total; Top = @($entries | Select-Object -First 3) }
}

# an operation $Count times after 200 for the warm-up (caches, lazily loaded DLLs: a few GDI objects were still
# created in the first few hundred tab switches); growth per 1000 operations allowed: 10 GDI and USER objects, 50
# handles (the system's own fluctuation), 8 MB of private memory, and with UMDH 256 KB of heap
function Measure-Op([string] $name, [scriptblock] $op) {
	for ($i = 0; $i -lt 200; $i++) { & $op }
	$before = Get-Counters
	$heapBefore = Join-Path $settings 'heap-before.txt'; $heapAfter = Join-Path $settings 'heap-after.txt'
	if ($script:useUmdh) { [void](Save-Heap $heapBefore) }
	for ($i = 0; $i -lt $Count; $i++) { & $op }
	$after = Get-Counters
	$per1000 = 1000 / $Count
	$gdi = ($after.Gdi - $before.Gdi) * $per1000; $user = ($after.User - $before.User) * $per1000
	$handles = ($after.Handles - $before.Handles) * $per1000; $mb = ($after.PrivateMB - $before.PrivateMB) * $per1000
	$detail = "per 1000: GDI {0:+0;-0;0}, USER {1:+0;-0;0}, handles {2:+0;-0;0}, private {3:+0.0;-0.0;0} MB (GDI {4}, USER {5}, handles {6}, {7} MB)" -f $gdi, $user, $handles, $mb, $after.Gdi, $after.User, $after.Handles, $after.PrivateMB
	# under AddressSanitizer (asan.ps1) freed memory stays in its quarantine: then objects and handles only
	$memoryOk = ($mb -le 8) -or [bool]$env:ASAN_OPTIONS
	if ($script:useUmdh) {
		[void](Save-Heap $heapAfter)
		$growth = Get-HeapGrowth $heapBefore $heapAfter (Join-Path $settings ("heap-diff-{0}.txt" -f ($name -replace '\W+', '-').Substring(0, [Math]::Min(30, $name.Length))))
		$heapKB = $growth.Bytes * $per1000 / 1KB
		$detail += "; heap {0:+0.0;-0.0;0} KB per 1000 (UMDH)" -f $heapKB
		$memoryOk = $memoryOk -and ($heapKB -le 256)
		if ($heapKB -gt 16) { foreach ($e in $growth.Top) { $script:results.Add("INFO    heap growth: $e") } }
	}
	Check "${name}: no leak over $Count" (($gdi -le 10) -and ($user -le 10) -and ($handles -le 50) -and $memoryOk) $detail
}

# a settings folder of its own: the Default Style in "Bahnschrift Light", a C++ and a Python file
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\leaks-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$model = Join-Path (Split-Path $Exe) 'stylers.model.xml'
if (Test-Path $model) {
	$stylers = [IO.File]::ReadAllText($model) -replace '(<WidgetStyle name="Default Style" styleID="32"[^>]*?)fontName="[^"]*"', '$1fontName="Bahnschrift Light"'
	[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $stylers, [Text.UTF8Encoding]::new($false))
}
$cpp = Join-Path $settings 'a.cpp'; [IO.File]::WriteAllLines($cpp, [string[]](1..200 | ForEach-Object { "int f$_() { return $_; } // line $_" }))
$py = Join-Path $settings 'b.py'; [IO.File]::WriteAllLines($py, [string[]](1..200 | ForEach-Object { "def f$_(): return $_  # line $_" }))
$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $cpp, $py -PassThru
$script:npid = $script:proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 1500
	$start = Get-Counters
	$script:results.Add("INFO  at start: GDI $($start.Gdi), USER $($start.User), handles $($start.Handles), private $($start.PrivateMB) MB")
	if ($script:useUmdh) {
		# Notepad++'s frames named from the build's .pdb, Windows' from Microsoft's symbol server
		$env:_NT_SYMBOL_PATH = "srv*C:\symbols*https://msdl.microsoft.com/download/symbols;$(Split-Path $Exe)"
		$probe = Save-Heap (Join-Path $settings 'heap-probe.txt')
		if ($probe -match 'Stack Trace Database|didn''t find any allocations') {
			$script:useUmdh = $false
			$script:results.Add('INFO  UMDH: this build records no allocation stacks (review\umdh-scope.ps1 sets that up): skipped')
		}
		else { $script:results.Add('INFO  UMDH: heap snapshots before and after each operation') }
	}

	Measure-Op 'tab switches (each styles the view again, the Default Style font of a weight)' { Invoke-Cmd $IDM_VIEW_TAB1; Invoke-Cmd $IDM_VIEW_TAB2 }
	Measure-Op 'Windows setting changes (WM_SETTINGCHANGE to Notepad++, passed on to its views)' {
		[void](Send-Sync $script:main $WM_SETTINGCHANGE ([IntPtr]$SPI_SETFONTSMOOTHING) ([IntPtr]::Zero))
	}
	# RTL with DirectWrite: refused with a message in builds without the RTL fix; then the operation is skipped
	[void][LK.U]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_EDIT_RTL, [IntPtr]::Zero); Start-Sleep -Milliseconds 800
	$box = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [LK.U]::IsWindowVisible($_) } | Select-Object -First 1
	if ($box) {
		[void][LK.U]::PostMessage($box, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 300
		$script:results.Add('INFO  right-to-left refused with DirectWrite in this build: skipped')
	}
	else {
		Invoke-Cmd $IDM_EDIT_LTR
		Measure-Op 'right-to-left and back (the view switches technology)' { Invoke-Cmd $IDM_EDIT_RTL; Invoke-Cmd $IDM_EDIT_LTR }
	}

	if ([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('graphics issues, restart Notepad++')) {
		$script:results.Add('INFO  no live rendering mode switch in this build: skipped')
	}
	else {
		Invoke-Cmd $IDM_SETTING_PREFERENCE
		$misc = $null
		for ($i = 0; $i -lt 50 -and -not $misc; $i++) {
			Start-Sleep -Milliseconds 100
			$pref = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1
			if ($pref) { $misc = Get-Kids $pref | Where-Object { [LK.U]::GetDlgItem($_, $IDC_COMBO_SC_TECHNOLOGY_CHOICE) -ne [IntPtr]::Zero } | Select-Object -First 1 }
		}
		$combo = if ($misc) { [LK.U]::GetDlgItem($misc, $IDC_COMBO_SC_TECHNOLOGY_CHOICE) } else { [IntPtr]::Zero }
		Check 'Preferences: the rendering mode box found' ($combo -ne [IntPtr]::Zero)
		if ($combo -ne [IntPtr]::Zero) {
			$script:mode = 0
			Measure-Op 'rendering mode switched (through every mode, both views and the Document Map)' {
				$script:mode = ($script:mode + 1) % 5
				[void][LK.U]::SendMessage($combo, $CB_SETCURSEL, [IntPtr]$script:mode, [IntPtr]::Zero)
				[void](Send-Sync $misc $WM_COMMAND $SELCHANGE $combo)
			}
			[void][LK.U]::SendMessage($combo, $CB_SETCURSEL, [IntPtr]1, [IntPtr]::Zero); [void](Send-Sync $misc $WM_COMMAND $SELCHANGE $combo)
			# Pyre909 build, on the same page, with DirectWrite again: the ligatures and the line spacing
			$ligatures = [LK.U]::GetDlgItem($misc, $IDC_CHECK_FONTLIGATURES); $spacing = [LK.U]::GetDlgItem($misc, $IDC_COMBO_LINESPACING)
			if (($ligatures -ne [IntPtr]::Zero) -and ($spacing -ne [IntPtr]::Zero)) {
				$script:on = $true
				Measure-Op 'font ligatures and line spacing off and on (the fonts realised again each time)' {
					$script:on = -not $script:on
					[void][LK.U]::SendMessage($ligatures, $BM_SETCHECK, [IntPtr][int]$script:on, [IntPtr]::Zero)
					[void](Send-Sync $misc $WM_COMMAND ([IntPtr]$IDC_CHECK_FONTLIGATURES) $ligatures)   # BN_CLICKED
					[void][LK.U]::SendMessage($spacing, $CB_SETCURSEL, [IntPtr]$(if ($script:on) { 0 } else { 3 }), [IntPtr]::Zero)
					[void](Send-Sync $misc $WM_COMMAND ([IntPtr]((1 -shl 16) -bor $IDC_COMBO_LINESPACING)) $spacing)   # CBN_SELCHANGE
				}
			}
			else { $script:results.Add('INFO  no font ligatures or line spacing option in this build: skipped') }
			[void][LK.U]::PostMessage($pref, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 300
		}
	}
	$end = Get-Counters
	$script:results.Add("INFO  at the end: GDI $($end.Gdi), USER $($end.User), handles $($end.Handles), private $($end.PrivateMB) MB")

	[void][LK.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	for ($i = 0; $i -lt 40 -and -not $script:proc.HasExited; $i++) {
		Start-Sleep -Milliseconds 250
		foreach ($b in @(Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [LK.U]::IsWindowVisible($_) })) {
			$no = [LK.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][LK.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][LK.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
		}
	}
	$exited = $script:proc.WaitForExit(15000)
	Check 'Notepad++ closes normally' ($exited -and $script:proc.ExitCode -eq 0) $(if ($exited) { "exit code $($script:proc.ExitCode)" } else { 'still running' })
}
finally {
	if (-not $script:proc.HasExited) { [void][LK.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -match '^(PASS|FAIL)' }).Count, $script:fails
}
