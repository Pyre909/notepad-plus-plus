# App-level test (review harness): with DirectWrite, the editor's font quality follows the Windows font smoothing
# (branch directwrite-font-smoothing_20261006, upstream issue #14954). DirectWrite antialiases text whatever the Windows
# setting ("Smooth edges of screen fonts" off, Standard or ClearType) while GDI follows it, so Notepad++ gives its
# DirectWrite views the matching Scintilla font quality: off SC_EFF_QUALITY_NON_ANTIALIASED (1), Standard
# SC_EFF_QUALITY_ANTIALIASED (2), ClearType SC_EFF_QUALITY_DEFAULT (0, as before), GDI views 0. "Enable smooth font"
# gives SC_EFF_QUALITY_LCD_OPTIMIZED (3). After a setting change (WM_SETTINGCHANGE), a view still at the quality it got
# from Windows follows it, and a view at another one ("Enable smooth font", a quality set by a plugin) keeps it.
# The test reads the Windows setting and never changes it, so it can't see a view follow a real change (checked by
# hand, kit section 8): it checks that setting changes leave the views alone. With ClearType, the Windows default, the
# views expect 0, as upstream already gives: turn the font smoothing off, or to Standard, yourself and run the test
# again, and unmodified upstream fails its quality checks.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
Add-Type -Namespace FQ -Name U -MemberDefinition @'
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
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint action, uint param, out uint value, uint winIni);
'@
$WM_CLOSE = 0x0010; $WM_SETTINGCHANGE = 0x001A; $WM_COMMAND = 0x0111; $CB_SETCURSEL = 0x014E
$SPI_GETFONTSMOOTHING = 0x004A; $SPI_SETFONTSMOOTHING = 0x004B; $SPI_SETWHEELSCROLLLINES = 0x0069
$SPI_GETFONTSMOOTHINGTYPE = 0x200A; $SPI_SETFONTSMOOTHINGTYPE = 0x200B
$IDM_VIEW_DOC_MAP = 44080; $IDM_SETTING_PREFERENCE = 48011; $IDC_COMBO_SC_TECHNOLOGY_CHOICE = 6362; $IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002
$NPPM_SETSMOOTHFONT = 2024 + 92
$SCI_SETFONTQUALITY = 2611; $SCI_GETFONTQUALITY = 2612; $SCI_GETTECHNOLOGY = 2631
$LCD_OPTIMIZED = 3

function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][FQ.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(512); [void][FQ.U]::GetWindowText($h, $sb, 512); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][FQ.U]::EnumWindows({ param($h, $l) $p = 0; [void][FQ.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][FQ.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Get-Views { $v = [Collections.Generic.List[IntPtr]]::new(); foreach ($t in (Get-Tops)) { if ((Get-Cls $t) -eq 'Scintilla') { $v.Add($t) }; foreach ($c in (Get-Kids $t)) { if ((Get-Cls $c) -eq 'Scintilla' -and -not $v.Contains($c)) { $v.Add($c) } } }; $v.ToArray() }
# the main and second views: the visible Scintillas whose parent is the Notepad++ window (the document is cloned into the
# second view to show it; Notepad++'s hidden working views, children of its window too, draw nothing and are left out)
function Get-MainViews { @(Get-Views | Where-Object { ([FQ.U]::GetParent($_) -eq $script:main) -and [FQ.U]::IsWindowVisible($_) }) }
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][FQ.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Cmd([int] $id) { [void](Send $script:main $WM_COMMAND $id); Start-Sleep -Milliseconds 400 }
function Describe([IntPtr[]] $views) { ($views | ForEach-Object { 'technology {0}, quality {1}' -f (Send $_ $SCI_GETTECHNOLOGY), (Send $_ $SCI_GETFONTQUALITY) }) -join '; ' }
function Test-Quality([IntPtr[]] $views, [int] $quality) { ($views.Count -gt 0) -and (@($views | Where-Object { (Send $_ $SCI_GETFONTQUALITY) -ne $quality }).Count -eq 0) }
function Test-Technology([IntPtr[]] $views, [int] $technology) { ($views.Count -eq 2) -and (@($views | Where-Object { (Send $_ $SCI_GETTECHNOLOGY) -ne $technology }).Count -eq 0) }
function Set-Quality([IntPtr[]] $views, [int] $quality) { foreach ($v in $views) { [void](Send $v $SCI_SETFONTQUALITY $quality) } }
# setting changes as Windows sends them to the Notepad++ window, which passes them on to its views (lParam NULL, as some
# senders do): the font smoothing, its type, another setting, and none named
function Send-SettingChanges { foreach ($spi in $SPI_SETFONTSMOOTHING, $SPI_SETFONTSMOOTHINGTYPE, $SPI_SETWHEELSCROLLLINES, 0) { [void](Send $script:main $WM_SETTINGCHANGE $spi 0) }; Start-Sleep -Milliseconds 300 }
function Wait-AnyBox([int] $tenths = 10) {
	for ($i = 0; $i -lt $tenths; $i++) {
		Start-Sleep -Milliseconds 100
		$b = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [FQ.U]::IsWindowVisible($_) } | Select-Object -First 1
		if ($b) { return $b }
	}
	$null
}
function Close-AnyBox([IntPtr] $b) { $no = [FQ.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][FQ.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][FQ.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) } }
function Box-Text([IntPtr] $b) { (Get-Txt $b) + ': ' + ((Get-Kids $b | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ') }
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Start-Npp {
	$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST' -PassThru
	$script:npid = $script:proc.Id
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	Cmd $IDM_VIEW_CLONE_TO_ANOTHER_VIEW
}
# no message on exit; a "Save file?" means a document was modified (maybe by input typed into the test window): answered No
function Stop-Npp([string] $what) {
	[void][FQ.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$boxes = @()
	for ($i = 0; $i -lt 60 -and -not $script:proc.HasExited; $i++) { $b = Wait-AnyBox 2; if ($b) { $boxes += Box-Text $b; Close-AnyBox $b } }
	Check "${what}: exit without a message" ($boxes.Count -eq 0) ($boxes -join '; ')
	$exited = $script:proc.WaitForExit(15000)
	Check "${what}: Notepad++ closes normally" ($exited -and $script:proc.ExitCode -eq 0) $(if ($exited) { "exit code $($script:proc.ExitCode)" } else { 'still running' })
}

# the Windows font smoothing, read only, and the quality a DirectWrite view gets from it
$smoothing = [uint32]0; [void][FQ.U]::SystemParametersInfo($SPI_GETFONTSMOOTHING, 0, [ref]$smoothing, 0)
$type = [uint32]0; [void][FQ.U]::SystemParametersInfo($SPI_GETFONTSMOOTHINGTYPE, 0, [ref]$type, 0)
$windows, $expected = if (-not $smoothing) { 'off', 1 } elseif ($type -eq 1) { 'Standard', 2 } else { 'ClearType', 0 }
$other = if ($expected -eq 2) { 1 } else { 2 } # a quality a view following Windows must not keep
"INFO  Windows font smoothing: $windows, so the DirectWrite views expect font quality $expected"

$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\directwrite-font-smoothing-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$script:proc = $null
try {
	# DirectWrite, the default of fresh settings
	Start-Npp
	$views = Get-MainViews
	Check 'DirectWrite (fresh settings): the main and second views on it' (Test-Technology $views 1) (Describe $views)
	Check "DirectWrite: both views at quality $expected (Windows: $windows)" (Test-Quality $views $expected) (Describe $views)
	$before = @(Get-Views); Cmd $IDM_VIEW_DOC_MAP; $map = @(Get-Views | Where-Object { $before -notcontains $_ })
	Check "DirectWrite: the Document Map at quality $expected" (Test-Quality $map $expected) $(if ($map.Count) { Describe $map } else { 'not found' })

	# "Enable smooth font" (Preferences > Editing 1, sends NPPM_SETSMOOTHFONT): ClearType quality, kept through setting changes
	[void](Send $script:main $NPPM_SETSMOOTHFONT 0 1)
	Check "smooth font on: both views at quality $LCD_OPTIMIZED" (Test-Quality $views $LCD_OPTIMIZED) (Describe $views)
	Send-SettingChanges
	Check "smooth font on, then setting changes: quality $LCD_OPTIMIZED kept" (Test-Quality $views $LCD_OPTIMIZED) (Describe $views)
	[void](Send $script:main $NPPM_SETSMOOTHFONT 0 0)
	Check "smooth font off: both views back at quality $expected" (Test-Quality $views $expected) (Describe $views)
	Send-SettingChanges
	Check "setting changes, the Windows font smoothing the same: quality $expected kept" (Test-Quality $views $expected) (Describe $views)

	# a quality set by a plugin (SCI_SETFONTQUALITY on the views) is kept through setting changes
	Set-Quality $views $other; Send-SettingChanges
	Check "a plugin's quality $other, then setting changes: kept" (Test-Quality $views $other) (Describe $views)
	[void](Send $script:main $NPPM_SETSMOOTHFONT 0 0)

	# the GDI rendering mode for the next start (Preferences > MISC., applied at restart)
	Cmd $IDM_SETTING_PREFERENCE
	$pref = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1
	$misc = Get-Kids $pref | Where-Object { [FQ.U]::GetDlgItem($_, $IDC_COMBO_SC_TECHNOLOGY_CHOICE) -ne [IntPtr]::Zero } | Select-Object -First 1
	$combo = [FQ.U]::GetDlgItem($misc, $IDC_COMBO_SC_TECHNOLOGY_CHOICE); [void][FQ.U]::SendMessage($combo, $CB_SETCURSEL, [IntPtr]0, [IntPtr]::Zero)
	[void](Send $misc $WM_COMMAND ((1 -shl 16) -bor $IDC_COMBO_SC_TECHNOLOGY_CHOICE) $combo.ToInt64())
	[void][FQ.U]::PostMessage($pref, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 500
	Stop-Npp 'DirectWrite'

	# GDI: the default quality as before, GDI follows the Windows font smoothing by itself
	Start-Npp
	$views = Get-MainViews
	Check 'GDI (chosen in Preferences, after a restart): the main and second views on it' (Test-Technology $views 0) (Describe $views)
	Check 'GDI: both views at quality 0' (Test-Quality $views 0) (Describe $views)
	[void](Send $script:main $NPPM_SETSMOOTHFONT 0 1); [void](Send $script:main $NPPM_SETSMOOTHFONT 0 0)
	Check 'GDI: smooth font on then off, quality 0' (Test-Quality $views 0) (Describe $views)
	Set-Quality $views $other; Send-SettingChanges
	Check "GDI: a plugin's quality $other, then setting changes: kept" (Test-Quality $views $other) (Describe $views)
	Stop-Npp 'GDI'
}
finally {
	if ($script:proc -and -not $script:proc.HasExited) { [void][FQ.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
