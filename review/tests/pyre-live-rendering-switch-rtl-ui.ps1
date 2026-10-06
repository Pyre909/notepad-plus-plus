# App-level test (review harness), pyre's version of live-rendering-switch-rtl-ui.ps1 as written for the pull request's
# commit 305ff13e7: the live rendering mode switch with a right-to-left UI language (hebrew.xml as nativeLang.xml), the
# box in Preferences > Editing 1. Every Scintilla inherits RTL from the mirrored Notepad++ window, the hidden ones
# included: only the RTL of the documents shown may block DirectWrite, never the hidden views (they would lock
# DirectWrite out). A build that isn't a Pyre909 build is skipped (0 checks).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe,
	[string] $LangXml = (Join-Path (Split-Path (Split-Path (Split-Path $Exe))) 'PowerEditor\installer\nativeLang\hebrew.xml'),
	[string] $TestFile = (Join-Path $PSScriptRoot '..\..\vm\weights.cpp'))
$ErrorActionPreference = 'Stop'
# a Pyre909 build names itself in its About box (PYRE_BUILD_TAG in AboutDlg.cpp)
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace LTR -Name U -MemberDefinition @'
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
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int idx);
[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $CB_SETCURSEL = 0x014E; $CB_GETCURSEL = 0x0147
$IDC_COMBO_SC_TECHNOLOGY_CHOICE = 6362; $SELCHANGE = [IntPtr]((1 -shl 16) -bor 6362)
$IDM_SETTING_PREFERENCE = 48011; $IDM_EDIT_LTR = 42027

function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][LTR.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(1024); [void][LTR.U]::GetWindowText($h, $sb, 1024); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][LTR.U]::EnumWindows({ param($h, $l) $p = 0; [void][LTR.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][LTR.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Get-Views { $v = [Collections.Generic.List[IntPtr]]::new(); foreach ($t in (Get-Tops)) { if ((Get-Cls $t) -eq 'Scintilla') { $v.Add($t) }; foreach ($c in (Get-Kids $t)) { if ((Get-Cls $c) -eq 'Scintilla' -and -not $v.Contains($c)) { $v.Add($c) } } }; $v.ToArray() }
function Get-Tech([IntPtr] $h) { $r = [IntPtr]::Zero; if ([LTR.U]::SendMessageTimeout($h, 2631, [IntPtr]::Zero, [IntPtr]::Zero, 2, 3000, [ref]$r) -eq [IntPtr]::Zero) { return -9 }; $r.ToInt64() }
function Test-RTL([IntPtr] $h) { ([LTR.U]::GetWindowLong($h, -20) -band 0x00400000) -ne 0 }
function Send-Sync([IntPtr] $h, [int] $msg, [IntPtr] $w, [IntPtr] $l) { $r = [IntPtr]::Zero; [void][LTR.U]::SendMessageTimeout($h, $msg, $w, $l, 2, 5000, [ref]$r); $r }
function Select-Mode([int] $idx, [switch] $Async) {
	[void][LTR.U]::SendMessage($script:combo, $CB_SETCURSEL, [IntPtr]$idx, [IntPtr]::Zero)
	if ($Async) { [void][LTR.U]::PostMessage($script:misc, $WM_COMMAND, $SELCHANGE, $script:combo) } else { [void](Send-Sync $script:misc $WM_COMMAND $SELCHANGE $script:combo) }
	Start-Sleep -Milliseconds 200
}
function Get-Sel { [LTR.U]::SendMessage($script:combo, $CB_GETCURSEL, [IntPtr]::Zero, [IntPtr]::Zero).ToInt64() }
function Wait-Box([string] $title, [int] $tenths = 50) {
	for ($i = 0; $i -lt $tenths; $i++) { Start-Sleep -Milliseconds 100; $b = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq $title } | Select-Object -First 1; if ($b) { return $b } }
	$null
}
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Check-All([string] $name, [int] $expected) {
	$vs = @(Get-Views); $ts = @($vs | ForEach-Object { Get-Tech $_ })
	Check $name ((@($ts | Where-Object { $_ -ne $expected }).Count -eq 0) -and $vs.Count -gt 0) ("{0} views: {1}" -f $vs.Count, ($ts -join ','))
}

if (-not (Test-Path $LangXml)) { "FAIL  no language file $LangXml"; '1 checks, 1 failed'; exit }
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\live-switch-rtl-ui-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
Copy-Item $LangXml (Join-Path $settings 'nativeLang.xml'); Copy-Item $TestFile $settings; $file = Join-Path $settings (Split-Path $TestFile -Leaf)
$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	$views = @(Get-Views)
	Check 'RTL UI: the Notepad++ window is mirrored' (Test-RTL $script:main)
	Check 'RTL UI: hidden views inherit RTL (the case that must not block DirectWrite)' (@($views | Where-Object { -not [LTR.U]::IsWindowVisible($_) -and (Test-RTL $_) }).Count -ge 1) ("{0} hidden RTL views" -f @($views | Where-Object { -not [LTR.U]::IsWindowVisible($_) -and (Test-RTL $_) }).Count)

	# Preferences: its titles are translated, so the page (Editing 1 on pyre) is found by the id of its rendering mode box
	[void](Send-Sync $script:main $WM_COMMAND ([IntPtr]$IDM_SETTING_PREFERENCE) ([IntPtr]::Zero))
	for ($i = 0; $i -lt 50 -and -not $script:misc; $i++) {
		Start-Sleep -Milliseconds 100
		foreach ($t in (Get-Tops)) { if ((Get-Cls $t) -eq '#32770') { $m = Get-Kids $t | Where-Object { [LTR.U]::GetDlgItem($_, $IDC_COMBO_SC_TECHNOLOGY_CHOICE) -ne [IntPtr]::Zero } | Select-Object -First 1; if ($m) { $script:misc = $m; break } } }
	}
	$script:combo = [LTR.U]::GetDlgItem($script:misc, $IDC_COMBO_SC_TECHNOLOGY_CHOICE)
	Check 'rendering mode box found' ($script:combo -ne [IntPtr]::Zero)

	Select-Mode 0; Check-All 'GDI applies' 0

	# the document shown is RTL (the default of an RTL UI language): DirectWrite is refused, the user can act on it
	Select-Mode 1 -Async
	$box = Wait-Box 'Cannot use DirectWrite'
	Check 'DirectWrite refused while the document shown is RTL' ($null -ne $box)
	if ($box) { [void][LTR.U]::PostMessage($box, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); for ($i = 0; $i -lt 30 -and [LTR.U]::IsWindow($box); $i++) { Start-Sleep -Milliseconds 100 } }
	Check 'refused: box back to GDI, no view switched' ((Get-Sel) -eq 0) ("sel " + (Get-Sel))
	Check-All 'refused: every view still GDI' 0

	# the document shown switched to LTR: DirectWrite applies, although the hidden views are still RTL
	[void](Send-Sync $script:main $WM_COMMAND ([IntPtr]$IDM_EDIT_LTR) ([IntPtr]::Zero)); Start-Sleep -Milliseconds 200
	Check 'hidden views still RTL' (@(Get-Views | Where-Object { -not [LTR.U]::IsWindowVisible($_) -and (Test-RTL $_) }).Count -ge 1)
	Select-Mode 1 -Async
	$box = Wait-Box 'Cannot use DirectWrite' 10
	Check 'document shown LTR: no refusal' ($null -eq $box)
	if ($box) { [void][LTR.U]::PostMessage($box, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 300 }
	Check-All 'DirectWrite applies to every view, hidden RTL ones included' 1

	# on exit the documents close and a new empty one (RTL by default with an RTL UI language) is activated: under
	# DirectWrite, upstream warns once that it can't show RTL ("Cannot run RTL"), the same as without this change
	[void][LTR.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$box = Wait-Box 'Cannot run RTL' 40
	if ($box) { $script:results.Add('INFO  exit: upstream''s "Cannot run RTL" warning for the new empty RTL document, closed'); [void][LTR.U]::PostMessage($box, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
	$exited = $proc.WaitForExit(15000)
	Check 'Notepad++ closes normally' ($exited -and $proc.ExitCode -eq 0) $(if ($exited) { "exit code $($proc.ExitCode)" } else { 'still running' })
}
finally {
	if (-not $proc.HasExited) { [void][LTR.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
