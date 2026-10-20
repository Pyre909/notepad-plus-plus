# App-level test (review harness), Pyre909 builds, with a person changing the Windows display scale: the per-monitor DPI
# awareness (Preferences > MISC.) following a real DPI change, which no message sent by a test can make (the panels read
# the DPI of their window). Run it with -WaitForScaleChange, then change Settings > System > Display > Scale (100% to
# 150%, say) once Notepad++ is shown, and back once told; each wait lasts up to 15 minutes. Without the switch: skipped.
# - Notepad++ starts per-monitor aware (perMonitorDpiAwareness="yes"), with the panels whose fonts and icons follow the
#   DPI: Function List, Folder as Workspace, Project Panel, Document List, Character Panel, Clipboard History, Document
#   Map, and the incremental search bar.
# - Each tree's item height, list view's height for 10 rows, list box's item height and toolbar's button height is read
#   before, after the change (scaled by the DPI ratio, within 25%) and after the change back (as before, 1 pixel at most).
# - The process stays alive and responsive; its GDI objects are reported (fonts and image lists replaced, not added).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [switch] $WaitForScaleChange, [int] $TimeoutMinutes = 15)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
if (-not $WaitForScaleChange) { 'INFO  needs a person to change the display scale (-WaitForScaleChange): skipped'; '0 checks, 0 failed'; exit }
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class DS {
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
	[DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
	[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr h);
	[DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c);
	[DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr hProcess, uint flags);
	[DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	public static void PerMonitorAware() { SetProcessDpiAwarenessContext(new IntPtr(-4)); }
}
'@
[DS]::PerMonitorAware()
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111
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

# every tree, list view, list box and toolbar of Notepad++'s windows, keyed by the dialog it's in, with its size
function Measure-Controls {
	$tops = [Collections.Generic.List[IntPtr]]::new()
	[void][DS]::EnumWindows({ param($h, $l) $p = 0; [void][DS]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:proc.Id) { $tops.Add($h) }; $true }, [IntPtr]::Zero)
	$all = [Collections.Generic.List[IntPtr]]::new()
	foreach ($t in $tops) { $all.Add($t); [void][DS]::EnumChildWindows($t, { param($h, $l) $all.Add($h); $true }, [IntPtr]::Zero) }
	$m = [ordered]@{}; $seen = @{}
	foreach ($h in $all) {
		$cls = Get-Cls $h   # hidden ones too: docked panels sharing a container are tabs, one shown at a time
		$value = switch ($cls) {
			'SysTreeView32' { [int](Send $h $TVM_GETITEMHEIGHT) }
			'SysListView32' { [int]((Send $h $LVM_APPROXIMATEVIEWRECT 10 0xFFFFFFFF) -shr 16 -band 0xFFFF) }
			'ListBox' { [int](Send $h $LB_GETITEMHEIGHT) }
			'ToolbarWindow32' { [int]((Send $h $TB_GETBUTTONSIZE) -shr 16 -band 0xFFFF) }
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
$folder = Join-Path $settings 'workspace'
New-Item -ItemType Directory -Force (Join-Path $folder 'sub') | Out-Null
[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), '<?xml version="1.0" encoding="UTF-8" ?><NotepadPlus><GUIConfigs><GUIConfig name="MISC" perMonitorDpiAwareness="yes" /></GUIConfigs></NotepadPlus>')
$file = Join-Path $folder 'functions.cpp'
[IO.File]::WriteAllLines($file, [string[]](1..40 | ForEach-Object { "int function$_(int a) { return a + $_; }" }))
try {
	$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', '-openFoldersAsWorkspace', "`"$folder`"", "`"$file`"" -PassThru
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	$awareness = [DS]::GetAwarenessFromDpiAwarenessContext([DS]::GetWindowDpiAwarenessContext($script:main))
	Check 'per-monitor DPI aware (perMonitorDpiAwareness="yes")' ($awareness -eq 2) "awareness $awareness"
	foreach ($cmd in $panelCommands.Values) { [void][DS]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$cmd, [IntPtr]::Zero); Start-Sleep -Milliseconds 400 }
	Start-Sleep -Seconds 2
	$dpi1 = [DS]::GetDpiForWindow($script:main); $gdi1 = Gdi
	$before = Measure-Controls
	Info "DPI $dpi1, GDI objects $gdi1; controls measured: $($before.Count)"
	foreach ($k in $before.Keys) { Info ("  {0} = {1}" -f $k, $before[$k]) }
	Check 'the panels'' controls found (trees, list views, list box, toolbars)' ($before.Count -ge 8) "$($before.Count) controls"

	Write-Host "NOW: change the display scale (Settings > System > Display > Scale), from $([math]::Round($dpi1 / 96 * 100))% to another"
	if (Wait-Dpi { param($d) $d -ne $dpi1 } 'scale change') {
		$dpi2 = [DS]::GetDpiForWindow($script:main); $ratio = $dpi2 / $dpi1
		Check "DPI change $dpi1 -> ${dpi2}: Notepad++ alive and responsive" (Responsive)
		$after = Measure-Controls
		$off = @($before.Keys | Where-Object { -not $after.Contains($_) -or [math]::Abs($after[$_] / $before[$_] - $ratio) -gt 0.25 * $ratio } |
			ForEach-Object { '{0}: {1} -> {2}' -f $_, $before[$_], $(if ($after.Contains($_)) { $after[$_] } else { 'missing' }) })
		Check ("every control rescaled by the DPI ratio {0:N2} (within 25%)" -f $ratio) ($off.Count -eq 0) $(if ($off) { $off -join '; ' } else { "$($before.Count) controls" })
		$gdi2 = Gdi; Info "GDI objects at DPI ${dpi2}: $gdi2"

		Write-Host "NOW: change the display scale back to $([math]::Round($dpi1 / 96 * 100))%"
		if (Wait-Dpi { param($d) $d -eq $dpi1 } 'change back') {
			Check "DPI back to ${dpi1}: Notepad++ alive and responsive" (Responsive)
			$back = Measure-Controls
			$diff = @($before.Keys | Where-Object { -not $back.Contains($_) -or [math]::Abs($back[$_] - $before[$_]) -gt 1 } |
				ForEach-Object { '{0}: {1} -> {2}' -f $_, $before[$_], $(if ($back.Contains($_)) { $back[$_] } else { 'missing' }) })
			Check 'every control back to its size (1 pixel at most)' ($diff.Count -eq 0) $(if ($diff) { $diff -join '; ' } else { "$($before.Count) controls" })
			$gdi3 = Gdi; Info "GDI objects back at DPI ${dpi1}: $gdi3 (at start $gdi1)"
		}
		else { Check 'DPI changed back' $false }
	}
	else { Check 'DPI changed' $false }
}
finally {
	if ($script:proc -and -not $script:proc.HasExited) { [void][DS]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notlike 'INFO*' }).Count, $script:fails
}
