# App-level test (review harness), Pyre909 builds, with a person changing the Windows display scale: the per-monitor DPI
# awareness (Preferences > MISC.) following real DPI changes, which no message sent by a test can make (the panels read
# the DPI of their window). Run it with -WaitForScaleChange, then change Settings > System > Display > Scale each time
# the test says so: -Changes times (2 by default: to another scale and back), the last one back to the start scale. Each
# wait lasts up to 15 minutes. Without the switch: skipped.
# - Notepad++ starts per-monitor aware (perMonitorDpiAwareness="yes"), maximized, with the panels whose fonts and icons
#   follow the DPI (Function List, Folder as Workspace, Project Panel, Document List, Character Panel, Clipboard History,
#   Document Map, the incremental search bar) and the Find dialog.
# - Each tree's item height, list view's height for 10 rows, list box's item height, toolbar's button height and status
#   bar's height is read at the start and after each change: at a new scale, the start's scaled by the DPI ratio (within
#   15%; a status bar below the start scale: no higher than at the start, comctl32 keeps it as high as for the system DPI
#   at least); at a scale seen before, the same as then (1 pixel at most).
# - At the start and after each change, the main window's status bar and the Find dialog's aren't mostly black (upstream's
#   #18462: with the Find dialog per-monitor aware, its status bar turned black after a scale change in light mode):
#   Notepad++ is brought to the front, each bar copied from the screen (PNG in the settings folder), black pixels counted.
# - -Compare <exe>,...: other builds (official, upstream) started alongside, maximized, with the Find dialog open, for the
#   status bar check only (INFO lines, not checks).
# - The process stays alive and responsive; its GDI objects are reported (fonts and image lists replaced, not added).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [switch] $WaitForScaleChange, [ValidateRange(2, 20)] [int] $Changes = 2,
	[string[]] $Compare = @(), [int] $TimeoutMinutes = 15)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
if (-not $WaitForScaleChange) { 'INFO  needs a person to change the display scale (-WaitForScaleChange): skipped'; '0 checks, 0 failed'; exit }
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class DS {
	public struct RECT { public int Left, Top, Right, Bottom; }
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
	[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
	[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
	[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr h);
	[DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c);
	[DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr hProcess, uint flags);
	[DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	public static void PerMonitorAware() { SetProcessDpiAwarenessContext(new IntPtr(-4)); }
	// the share of pixels (32-bit ARGB) whose red, green and blue are all under 16
	public static double BlackShare(int[] px) { int n = 0; foreach (int p in px) if ((p & 0xF0F0F0) == 0) n++; return px.Length == 0 ? 0 : (double)n / px.Length; }
}
'@
[DS]::PerMonitorAware()
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $IDM_SEARCH_FIND = 43001
$TVM_GETITEMHEIGHT = 0x111C; $LVM_APPROXIMATEVIEWRECT = 0x1040; $LB_GETITEMHEIGHT = 0x01A1; $TB_GETBUTTONSIZE = 0x043A
$panelCommands = [ordered]@{ 'Function List' = 44084; 'Project Panel' = 44081; 'Document List' = 44070; 'Character Panel' = 42051;
	'Clipboard History' = 42052; 'Document Map' = 44080; 'incremental search' = 43011 }

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Info([string] $text) { $script:results.Add("INFO  $text") }
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][DS]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][DS]::GetWindowText($h, $sb, 256); $sb.ToString() }
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][DS]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Responsive { $r = [IntPtr]::Zero; -not $script:proc.HasExited -and ([DS]::SendMessageTimeout($script:main, 0, [IntPtr]::Zero, [IntPtr]::Zero, 2, 5000, [ref]$r) -ne [IntPtr]::Zero) }
function Gdi { $script:proc.Refresh(); [DS]::GetGuiResources($script:proc.Handle, 0) }
function Pct([uint32] $dpi) { [math]::Round($dpi / 96 * 100) }
function Get-TopWindows([int] $processId) {
	$tops = [Collections.Generic.List[IntPtr]]::new()
	[void][DS]::EnumWindows({ param($h, $l) $p = 0; [void][DS]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $processId) { $tops.Add($h) }; $true }, [IntPtr]::Zero)
	$tops
}
function Get-Children([IntPtr] $parent, [string] $cls) {
	$found = [Collections.Generic.List[IntPtr]]::new()
	[void][DS]::EnumChildWindows($parent, { param($h, $l) if ((Get-Cls $h) -eq $cls -and [DS]::GetParent($h) -eq $parent) { $found.Add($h) }; $true }, [IntPtr]::Zero)
	$found
}

# a Notepad++ process started maximized with the Find dialog open, moved to the top right of the screen
function Start-Npp([string] $exe, [string] $settings, [string[]] $arguments = @()) {
	$p = Start-Process $exe -ArgumentList (@('-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST') + $arguments) -PassThru
	for ($i = 0; $i -lt 100; $i++) { $p.Refresh(); if ($p.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$main = $p.MainWindowHandle; Start-Sleep -Milliseconds 800
	[void][DS]::ShowWindow($main, 3)   # SW_MAXIMIZE
	[void][DS]::PostMessage($main, $WM_COMMAND, [IntPtr]$IDM_SEARCH_FIND, [IntPtr]::Zero)
	$find = [IntPtr]::Zero
	for ($i = 0; $i -lt 50 -and $find -eq [IntPtr]::Zero; $i++) {
		Start-Sleep -Milliseconds 100
		$find = @(Get-TopWindows $p.Id | Where-Object { (Get-Cls $_) -eq '#32770' -and [DS]::IsWindowVisible($_) -and (Get-Children $_ 'msctls_statusbar32').Count }) | Select-Object -First 1
		if (-not $find) { $find = [IntPtr]::Zero }
	}
	if ($find -ne [IntPtr]::Zero) {
		$m = New-Object DS+RECT; $f = New-Object DS+RECT; [void][DS]::GetWindowRect($main, [ref]$m); [void][DS]::GetWindowRect($find, [ref]$f)
		[void][DS]::SetWindowPos($find, [IntPtr]::Zero, $m.Right - ($f.Right - $f.Left) - 60, $m.Top + 120, 0, 0, 0x0001 -bor 0x0004 -bor 0x0010)   # NOSIZE, NOZORDER, NOACTIVATE
	}
	[pscustomobject]@{ Process = $p; Main = $main; Find = $find }
}

# every tree, list view, list box, toolbar and status bar of Notepad++'s windows, keyed by the dialog it's in, with its size
function Measure-Controls {
	$all = [Collections.Generic.List[IntPtr]]::new()
	foreach ($t in (Get-TopWindows $script:proc.Id)) { $all.Add($t); [void][DS]::EnumChildWindows($t, { param($h, $l) $all.Add($h); $true }, [IntPtr]::Zero) }
	$m = [ordered]@{}; $seen = @{}
	foreach ($h in $all) {
		$cls = Get-Cls $h   # hidden ones too: docked panels sharing a container are tabs, one shown at a time
		$value = switch ($cls) {
			'SysTreeView32' { [int](Send $h $TVM_GETITEMHEIGHT) }
			'SysListView32' { [int]((Send $h $LVM_APPROXIMATEVIEWRECT 10 0xFFFFFFFF) -shr 16 -band 0xFFFF) }
			'ListBox' { [int](Send $h $LB_GETITEMHEIGHT) }
			'ToolbarWindow32' { [int]((Send $h $TB_GETBUTTONSIZE) -shr 16 -band 0xFFFF) }
			'msctls_statusbar32' { $r = New-Object DS+RECT; [void][DS]::GetClientRect($h, [ref]$r); $r.Bottom - $r.Top }
			default { $null }
		}
		if ($null -eq $value -or $value -le 0) { continue }
		# the dialog the control is in: the nearest #32770 with a title (the panels), else its parent's class
		$owner = [DS]::GetParent($h); $title = ''
		while ($owner -ne [IntPtr]::Zero -and -not $title) { if ((Get-Cls $owner) -eq '#32770') { $title = Get-Txt $owner }; if (-not $title) { $owner = [DS]::GetParent($owner) } }
		if (-not $title) { $title = Get-Cls ([DS]::GetParent($h)) }
		$key = "$title / $cls"; $n = 1 + [int]$seen[$key]; $seen[$key] = $n
		$m["$key #$n"] = $value
	}
	$m
}

# the share of black pixels of a window as shown on the screen, the copy saved as a PNG
function Get-BlackShare([IntPtr] $h, [string] $png) {
	$r = New-Object DS+RECT; [void][DS]::GetWindowRect($h, [ref]$r)
	$w = $r.Right - $r.Left; $hgt = $r.Bottom - $r.Top
	if ($w -le 0 -or $hgt -le 0) { return -1 }
	$bmp = [Drawing.Bitmap]::new($w, $hgt, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
	try {
		$g = [Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size); $g.Dispose()
		$bmp.Save($png, [Drawing.Imaging.ImageFormat]::Png)
		$data = $bmp.LockBits([Drawing.Rectangle]::new(0, 0, $w, $hgt), [Drawing.Imaging.ImageLockMode]::ReadOnly, $bmp.PixelFormat)
		$px = [int[]]::new($w * $hgt); [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $px, 0, $px.Length); $bmp.UnlockBits($data)   # stride 4 * width
		[DS]::BlackShare($px)
	}
	finally { $bmp.Dispose() }
}
function Front([IntPtr] $h) {
	[DS]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [DS]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)   # Alt: lets this process set the foreground
	[void][DS]::SetForegroundWindow($h); Start-Sleep -Milliseconds 700
}
# the main window's status bar and the Find dialog's of each build, brought to the front in turn
function Test-StatusBars([string] $tag) {
	foreach ($npp in $script:npps) {
		if ($npp.Process.HasExited) { Info "${tag}: $($npp.Label) has exited"; continue }
		Front $npp.Main
		$bars = [ordered]@{ 'main window' = @(Get-Children $npp.Main 'msctls_statusbar32') | Select-Object -First 1 }
		if ($npp.Find -ne [IntPtr]::Zero) { $bars['Find dialog'] = @(Get-Children $npp.Find 'msctls_statusbar32') | Select-Object -First 1 }
		foreach ($name in $bars.Keys) {
			$png = Join-Path $script:shots ("{0}-{1}-{2}.png" -f $tag, $npp.Label, ($name -replace ' ', '-'))
			$share = if ($bars[$name]) { Get-BlackShare $bars[$name] $png } else { -1 }
			$dpi = if ($name -eq 'Find dialog') { [DS]::GetDpiForWindow($npp.Find) } else { [DS]::GetDpiForWindow($npp.Main) }
			$detail = if ($share -lt 0) { 'not found' } else { "{0:P0} black, DPI {1}, {2}" -f $share, $dpi, (Split-Path -Leaf $png) }
			if ($npp.IsUnderTest) { Check "${tag}: the $name's status bar not black" ($share -ge 0 -and $share -lt 0.5) $detail }
			else { Info "${tag}: $($npp.Label): the $name's status bar: $detail" }
		}
	}
}
function Wait-Dpi([scriptblock] $done, [string] $what) {
	$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
	while ((Get-Date) -lt $deadline) {
		if ($script:proc.HasExited) { return $false }
		$d = [DS]::GetDpiForWindow($script:main)
		if (& $done $d) { Start-Sleep -Seconds 3; return $true }   # the relayout posted after WM_DPICHANGED
		Start-Sleep -Milliseconds 500
	}
	Info "no $what within $TimeoutMinutes minutes"; $false
}

$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-dpi-scale-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$folder = Join-Path $settings 'workspace'; $script:shots = Join-Path $settings 'shots'
New-Item -ItemType Directory -Force (Join-Path $folder 'sub'), $script:shots | Out-Null
[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), '<?xml version="1.0" encoding="UTF-8" ?><NotepadPlus><GUIConfigs><GUIConfig name="MISC" perMonitorDpiAwareness="yes" /></GUIConfigs></NotepadPlus>')
$file = Join-Path $folder 'functions.cpp'
[IO.File]::WriteAllLines($file, [string[]](1..40 | ForEach-Object { "int function$_(int a) { return a + $_; }" }))
$script:npps = [Collections.Generic.List[object]]::new()
try {
	$npp = Start-Npp $Exe $settings @('-openFoldersAsWorkspace', "`"$folder`"", "`"$file`"")
	$script:proc = $npp.Process; $script:main = $npp.Main
	$script:npps.Add(($npp | Add-Member -PassThru -NotePropertyMembers @{ Label = 'tested'; Exe = $Exe; IsUnderTest = $true }))
	$n = 0
	foreach ($other in $Compare) {
		$n++; $dir = Join-Path $settings "compare$n"; New-Item -ItemType Directory -Force $dir | Out-Null
		$c = Start-Npp $other $dir
		$script:npps.Add(($c | Add-Member -PassThru -NotePropertyMembers @{ Label = "compare$n"; Exe = $other; IsUnderTest = $false }))
		Info ("compare{0}: {1}, Find dialog {2}" -f $n, $other, $(if ($c.Find -ne [IntPtr]::Zero) { "open, DPI awareness $([DS]::GetAwarenessFromDpiAwarenessContext([DS]::GetWindowDpiAwarenessContext($c.Find)))" } else { 'not found' }))
	}
	$awareness = [DS]::GetAwarenessFromDpiAwarenessContext([DS]::GetWindowDpiAwarenessContext($script:main))
	Check 'per-monitor DPI aware (perMonitorDpiAwareness="yes")' ($awareness -eq 2) "awareness $awareness"
	Check 'the Find dialog open' ($npp.Find -ne [IntPtr]::Zero)
	foreach ($cmd in $panelCommands.Values) { [void][DS]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$cmd, [IntPtr]::Zero); Start-Sleep -Milliseconds 400 }
	Start-Sleep -Seconds 2
	$dpi1 = [DS]::GetDpiForWindow($script:main); $gdi1 = Gdi
	$before = Measure-Controls
	Info "DPI $dpi1, GDI objects $gdi1; controls measured: $($before.Count)"
	foreach ($k in $before.Keys) { Info ("  {0} = {1}" -f $k, $before[$k]) }
	Check 'the panels'' controls found (trees, list views, list box, toolbars, status bars)' ($before.Count -ge 10) "$($before.Count) controls"
	Test-StatusBars 'start'

	$readings = @{ $dpi1 = $before }   # the first reading at each DPI
	$current = $dpi1
	for ($i = 1; $i -le $Changes; $i++) {
		$isLast = $i -eq $Changes
		if ($isLast) { Write-Host "NOW (change $i of $Changes): change the display scale back to $(Pct $dpi1)%" }
		else { Write-Host "NOW (change $i of $Changes): change the display scale to another one than $(Pct $current)% (Notepad++ comes to the front for a moment after each change)" }
		$changed = if ($isLast) { Wait-Dpi { param($d) $d -eq $dpi1 } 'change back' } else { Wait-Dpi { param($d) $d -ne $current } 'scale change' }
		if (-not $changed) { Check "scale change $i" $false; break }
		$dpi = [DS]::GetDpiForWindow($script:main); $tag = "change$i-$(Pct $dpi)"
		Check "change ${i}: DPI $current -> ${dpi}: Notepad++ alive and responsive" (Responsive)
		$now = Measure-Controls
		if ($readings.ContainsKey($dpi)) {
			$earlier = $readings[$dpi]
			$diff = @($earlier.Keys | Where-Object { -not $now.Contains($_) -or [math]::Abs($now[$_] - $earlier[$_]) -gt 1 } |
				ForEach-Object { '{0}: {1} -> {2}' -f $_, $earlier[$_], $(if ($now.Contains($_)) { $now[$_] } else { 'missing' }) })
			Check "change ${i}: every control as at $(Pct $dpi)% before (1 pixel at most)" ($diff.Count -eq 0) $(if ($diff) { $diff -join '; ' } else { "$($earlier.Count) controls" })
		}
		else {
			# a status bar below the start scale: comctl32 keeps it at least as high as for the system DPI (the start's)
			$ratio = $dpi / $dpi1
			$off = @($before.Keys | Where-Object { -not $now.Contains($_) -or $(
					if ($_ -like '*msctls_statusbar32*' -and $ratio -lt 1) { $now[$_] -gt $before[$_] }
					else { [math]::Abs($now[$_] / $before[$_] - $ratio) -gt 0.15 * $ratio }) } |
				ForEach-Object { '{0}: {1} -> {2}' -f $_, $before[$_], $(if ($now.Contains($_)) { $now[$_] } else { 'missing' }) })
			Check ("change ${i}: every control rescaled by the DPI ratio {0:N2} (within 15%)" -f $ratio) ($off.Count -eq 0) $(if ($off) { $off -join '; ' } else { "$($before.Count) controls" })
			$readings[$dpi] = $now
		}
		Info ("  at DPI ${dpi}: " + (($now.Keys | ForEach-Object { '{0} = {1}' -f $_, $now[$_] }) -join '; '))
		Test-StatusBars $tag
		Info "GDI objects at DPI ${dpi}: $(Gdi) (at start $gdi1)"
		$current = $dpi
		if (-not $isLast) { Write-Host '  (measured: switch back to Settings)' }
	}
}
finally {
	foreach ($npp in $script:npps) {
		if (-not $npp.Process.HasExited) { [void][DS]::PostMessage($npp.Main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $npp.Process.WaitForExit(10000)) { Stop-Process -Id $npp.Process.Id -Force } }
	}
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notlike 'INFO*' }).Count, $script:fails
}
