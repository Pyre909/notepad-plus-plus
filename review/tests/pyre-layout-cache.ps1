# App-level test (review harness), Pyre909 builds only: the layout cache of 2026-10-19 and what came of its review.
# - The edit views keep the layouts of the lines shown (SC_CACHE_PAGE, multiple phases), not for a large file (a file of
#   2 MB with the large file size set to 1 MB: caret cache, two phases), nor the Document Map (Scintilla's defaults).
# - A kept layout is laid out again when its tab stops change (SCI_ADDTABSTOP / SCI_CLEARTABSTOPS: the ElasticTabstops
#   plugin) and when a representation changes (SCI_SETREPRESENTATION: Preferences > Editing 2 > Non-Printing
#   Characters, abbreviation or codepoint, shown with View > Show Symbol > Show Non-Printing Characters).
# - Replace All adding a line per match with the document cloned in the other view: the redraw of both views is off
#   during it (upstream #10301), so it doesn't take minutes; both views are shown again afterwards.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [int] $ReplaceLines = 200000, [int] $ReplaceSecondsMax = 15)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class LC {
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr SendMessageStr(IntPtr h, uint m, IntPtr w, string l);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
	[DllImport("user32.dll")] public static extern bool UpdateWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int index);
	[DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	public static void PerMonitorAware() { SetProcessDpiAwarenessContext(new IntPtr(-4)); }
}
'@
[LC]::PerMonitorAware()
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $WM_SETTEXT = 0x000C; $BM_SETCHECK = 0x00F1; $GWL_STYLE = -16; $WS_VISIBLE = 0x10000000
$IDM_SETTING_PREFERENCE = 48011; $IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002; $IDM_VIEW_DOC_MAP = 44080; $IDM_VIEW_NPC = 44130
$IDM_VIEW_TAB1 = 44086; $IDM_VIEW_TAB2 = 44087; $IDM_SEARCH_REPLACE = 43003
$IDC_RADIO_NPC_ABBREVIATION = 6254; $IDC_RADIO_NPC_CODEPOINT = 6255
$SCI_GETLAYOUTCACHE = 2273; $SCI_GETPHASESDRAW = 2673; $SCI_POINTXFROMPOSITION = 2164; $SCI_POSITIONFROMLINE = 2167
$SCI_ADDTABSTOP = 2676; $SCI_CLEARTABSTOPS = 2675; $SCI_GETLINECOUNT = 2154; $SCI_GOTOPOS = 2025

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][LC]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][LC]::GetWindowText($h, $sb, 256); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][LC]::EnumWindows({ param($h, $l) $p = 0; [void][LC]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	$script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][LC]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids.ToArray()
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0, [int] $timeout = 5000) { $r = [IntPtr]::Zero; [void][LC]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, $timeout, [ref]$r); $r.ToInt64() }
function Get-Views { @(Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [LC]::IsWindowVisible($_) -and ([LC]::GetParent($_) -eq $script:main) }) }
function Shown([IntPtr] $h) { ([LC]::GetWindowLong($h, $GWL_STYLE) -band $WS_VISIBLE) -ne 0 }
# a dialog of Notepad++ by its title, then its child page holding a control
function Find-Page([string] $title, [int] $controlId) {
	for ($i = 0; $i -lt 50; $i++) {
		$dlg = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq $title -and [LC]::IsWindowVisible($_) } | Select-Object -First 1
		if ($dlg) {
			if ([LC]::GetDlgItem($dlg, $controlId) -ne [IntPtr]::Zero) { return $dlg }
			$page = Get-Kids $dlg | Where-Object { [LC]::GetDlgItem($_, $controlId) -ne [IntPtr]::Zero } | Select-Object -First 1
			if ($page) { return $page }
		}
		Start-Sleep -Milliseconds 100
	}
	[IntPtr]::Zero
}

# settings: a large file from 1 MB on; the files: tab-separated lines (CRLF), a 2 MB file, the lines to replace in
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-layout-cache-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), @'
<?xml version="1.0" encoding="UTF-8" ?>
<NotepadPlus>
    <GUIConfigs>
        <GUIConfig name="largeFileRestriction" fileSizeMB="1" isEnabled="yes" allowAutoCompletion="no" allowBraceMatch="no" allowSmartHilite="no" allowClickableLink="no" deactivateWordWrap="yes" suppress2GBWarning="no" />
    </GUIConfigs>
</NotepadPlus>
'@)
$tabs = Join-Path $settings 'tabs.txt'; $nbspLine = 10   # a no-break space on that line
[IO.File]::WriteAllLines($tabs, [string[]](1..30 | ForEach-Object { if ($_ -eq $nbspLine + 1) { "x$([char]0x00A0)y" } else { "a`tb`tc $_" } }), [Text.UTF8Encoding]::new($true))
$large = Join-Path $settings 'large.txt'; [IO.File]::WriteAllLines($large, [string[]](1..30000 | ForEach-Object { "line $_ of a file over the large file size, made long enough to reach 2 MB" }))
$lines = Join-Path $settings 'lines.cpp'; [IO.File]::WriteAllLines($lines, [string[]](1..$ReplaceLines | ForEach-Object { "int v$_ = $_; // line $_" }))

$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $tabs, $large -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 1000
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_TAB1); Start-Sleep -Milliseconds 300
	$view = (Get-Views)[0]

	# the cache of an edit view, of a large file's, of the Document Map
	Check 'edit view: page layout cache, multiple phases' (((Send $view $SCI_GETLAYOUTCACHE) -eq 2) -and ((Send $view $SCI_GETPHASESDRAW) -eq 2)) "cache $(Send $view $SCI_GETLAYOUTCACHE), phases $(Send $view $SCI_GETPHASESDRAW)"
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_TAB2); Start-Sleep -Milliseconds 500
	Check 'large file: caret cache, two phases' (((Send $view $SCI_GETLAYOUTCACHE) -eq 1) -and ((Send $view $SCI_GETPHASESDRAW) -eq 1)) "cache $(Send $view $SCI_GETLAYOUTCACHE), phases $(Send $view $SCI_GETPHASESDRAW)"
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_TAB1); Start-Sleep -Milliseconds 500
	Check '  back to the small file: page cache, multiple phases' (((Send $view $SCI_GETLAYOUTCACHE) -eq 2) -and ((Send $view $SCI_GETPHASESDRAW) -eq 2))
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_DOC_MAP); Start-Sleep -Milliseconds 800
	$map = @(Get-Tops | ForEach-Object { Get-Kids $_ } | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [LC]::IsWindowVisible($_) -and ([LC]::GetParent($_) -ne $script:main) }) | Select-Object -First 1
	Check 'Document Map: Scintilla''s caret cache and two phases' ($map -and ((Send $map $SCI_GETLAYOUTCACHE) -eq 1) -and ((Send $map $SCI_GETPHASESDRAW) -eq 1)) $(if ($map) { "cache $(Send $map $SCI_GETLAYOUTCACHE), phases $(Send $map $SCI_GETPHASESDRAW)" } else { 'no map view' })
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_DOC_MAP); Start-Sleep -Milliseconds 300

	# tab stops of a line whose layout is kept (the line is shown, the view painted)
	[void][LC]::UpdateWindow($view)
	$line = 5; $start = Send $view $SCI_POSITIONFROMLINE $line
	$xStart = Send $view $SCI_POINTXFROMPOSITION 0 $start
	$xB = Send $view $SCI_POINTXFROMPOSITION 0 ($start + 2)          # after "a<tab>"
	$xOther = Send $view $SCI_POINTXFROMPOSITION 0 ((Send $view $SCI_POSITIONFROMLINE ($line + 1)) + 2)
	$stop = [int](($xB - $xStart) * 3)                               # a tab stop well after the default one
	[void](Send $view $SCI_ADDTABSTOP $line $stop); [void][LC]::UpdateWindow($view)
	$xB2 = Send $view $SCI_POINTXFROMPOSITION 0 ($start + 2)
	Check 'SCI_ADDTABSTOP: the kept line laid out with the new tab stop' ($xB2 -eq $xStart + $stop) "x of b: $xB -> $xB2, expected $($xStart + $stop)"
	Check '  the next line unchanged' ((Send $view $SCI_POINTXFROMPOSITION 0 ((Send $view $SCI_POSITIONFROMLINE ($line + 1)) + 2)) -eq $xOther)
	[void](Send $view $SCI_CLEARTABSTOPS $line); [void][LC]::UpdateWindow($view)
	Check 'SCI_CLEARTABSTOPS: back to the default tab stops' ((Send $view $SCI_POINTXFROMPOSITION 0 ($start + 2)) -eq $xB)

	# a representation changed (SCI_SETREPRESENTATION): the no-break space shown as "NBSP", then as "U+00A0" (Preferences >
	# Editing 2 > Non-Printing Characters), with View > Show Symbol > Show Non-Printing Characters; the x of the "y" after it
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_NPC); Start-Sleep -Milliseconds 300; [void][LC]::UpdateWindow($view)
	$yPos = (Send $view $SCI_POSITIONFROMLINE $nbspLine) + 3   # "x", then the 2 bytes of U+00A0
	$xAbbreviation = Send $view $SCI_POINTXFROMPOSITION 0 $yPos
	[void](Send $script:main $WM_COMMAND $IDM_SETTING_PREFERENCE)
	$editing2 = Find-Page 'Preferences' $IDC_RADIO_NPC_CODEPOINT
	if ($editing2 -eq [IntPtr]::Zero) { Check 'Preferences > Editing 2: the Non-Printing Characters boxes found' $false }
	else {
		foreach ($pair in @(@($IDC_RADIO_NPC_CODEPOINT, $IDC_RADIO_NPC_ABBREVIATION), @($IDC_RADIO_NPC_ABBREVIATION, $IDC_RADIO_NPC_CODEPOINT))) {
			[void](Send ([LC]::GetDlgItem($editing2, $pair[1])) $BM_SETCHECK 0); [void](Send ([LC]::GetDlgItem($editing2, $pair[0])) $BM_SETCHECK 1)
			[void](Send $editing2 $WM_COMMAND $pair[0] ([LC]::GetDlgItem($editing2, $pair[0])).ToInt64())   # BN_CLICKED
			Start-Sleep -Milliseconds 300; [void][LC]::UpdateWindow($view)
			$x = Send $view $SCI_POINTXFROMPOSITION 0 $yPos
			if ($pair[0] -eq $IDC_RADIO_NPC_CODEPOINT) { Check 'SCI_SETREPRESENTATION: "U+00A0" wider than "NBSP" in the kept line' ($x -gt $xAbbreviation) "x of y: $xAbbreviation -> $x" }
			else { Check '  "NBSP" again: where it was' ($x -eq $xAbbreviation) "x of y: $x, expected $xAbbreviation" }
		}
		[void][LC]::PostMessage((Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1), $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
		Start-Sleep -Milliseconds 300
	}
	# Notepad++ restyles the view after those (so its layouts are laid out again anyway): Scintilla's message alone, as
	# a plugin may send it: back to no representation for the no-break space, narrower than "NBSP"
	[void](Send $view 2770); [void][LC]::UpdateWindow($view)   # SCI_CLEARALLREPRESENTATIONS
	$x = Send $view $SCI_POINTXFROMPOSITION 0 $yPos
	Check 'SCI_CLEARALLREPRESENTATIONS alone: the kept line laid out without "NBSP"' ($x -lt $xAbbreviation) "x of y: $xAbbreviation -> $x"
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_NPC); Start-Sleep -Milliseconds 300

	# Replace All adding a line per match, the document cloned in the other view
	[void][LC]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); [void]$proc.WaitForExit(10000)
	$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $lines -PassThru
	$script:npid = $proc.Id
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 1000
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_CLONE_TO_ANOTHER_VIEW); Start-Sleep -Milliseconds 500
	$views = Get-Views
	[void](Send $views[0] $SCI_GOTOPOS 0)
	[void](Send $script:main $WM_COMMAND $IDM_SEARCH_REPLACE)
	$replace = Find-Page 'Replace' 1609
	[void][LC]::SendMessageStr([LC]::GetDlgItem($replace, 1601), $WM_SETTEXT, [IntPtr]::Zero, '; //')
	[void][LC]::SendMessageStr([LC]::GetDlgItem($replace, 1602), $WM_SETTEXT, [IntPtr]::Zero, ';\r\n//')
	[void](Send ([LC]::GetDlgItem($replace, 1625)) $BM_SETCHECK 0); [void](Send ([LC]::GetDlgItem($replace, 1626)) $BM_SETCHECK 1)
	[void](Send $replace $WM_COMMAND 1626 ([LC]::GetDlgItem($replace, 1626)).ToInt64())   # Extended mode
	$sw = [Diagnostics.Stopwatch]::StartNew()
	[void](Send $replace $WM_COMMAND 1609 ([LC]::GetDlgItem($replace, 1609)).ToInt64() ($ReplaceSecondsMax * 20000))   # Replace All
	$seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
	$counts = @($views | ForEach-Object { Send $_ $SCI_GETLINECOUNT })
	Check "Replace All, $ReplaceLines lines added, the document in both views: under $ReplaceSecondsMax s" (($seconds -lt $ReplaceSecondsMax) -and (@($counts | Where-Object { $_ -eq (2 * $ReplaceLines + 1) }).Count -eq 2)) "$seconds s, line counts $($counts -join ', ')"
	Check '  both views shown again' (@($views | Where-Object { Shown $_ }).Count -eq 2)
}
finally {
	if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
