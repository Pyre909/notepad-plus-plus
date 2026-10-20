# App-level test (review harness), Pyre909 builds only: Windows 11 rounded corners on the popups it leaves square
# (Preferences > Dark Mode > "Rounded corners on popups (Windows 11)", NppDarkMode::setRoundedCorners).
# - On by default: the About box and the colour picker popup ask for DWMWCP_ROUND, a call tip (the Find dialog's tip for
#   a zero-length match) for DWMWCP_ROUNDSMALL; the main window is left to Windows (DWMWCP_DEFAULT).
# - Turned off in Preferences: the same popups shown again ask for DWMWCP_DEFAULT (square) at once, without a restart.
#   Call tips and the colour popup are new windows at each showing (square until asked otherwise), so only the About
#   box, kept between showings, proves the switch acts on a window that was rounded; the others check what's seen.
# - Saved in config.xml (MISC roundedPopups="no") and read back at the next start.
# Reads what each window asked DWM for (DwmGetWindowAttribute DWMWA_WINDOW_CORNER_PREFERENCE), no screenshots. The
# document peeker isn't driven: it shows only while the real mouse is over a tab. Skipped before Windows 11, where the
# option is disabled.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
if ([Environment]::OSVersion.Version.Build -lt 22000) { 'INFO  Windows 10: the option is disabled there: skipped'; '0 checks, 0 failed'; exit }
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class RP {
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
	[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageTimeoutW")] public static extern IntPtr SendText(IntPtr h, uint m, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
	[DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, uint a, out int v, int size);
	// DWMWA_WINDOW_CORNER_PREFERENCE: 0 default, 1 do not round, 2 round, 3 round small; -1 if it can't be read
	public static int Corner(IntPtr h) { int v; return DwmGetWindowAttribute(h, 33, out v, 4) == 0 ? v : -1; }
}
'@
$WM_CLOSE = 0x0010; $WM_SETTEXT = 0x000C; $WM_COMMAND = 0x0111; $WM_LBUTTONDOWN = 0x0201; $BM_SETCHECK = 0x00F1; $BM_GETCHECK = 0x00F0
$IDM_ABOUT = 47000; $IDM_LANGSTYLE_CONFIG_DLG = 46001; $IDM_SEARCH_FIND = 43001; $IDM_SETTING_PREFERENCE = 48011
$IDFINDWHAT = 1601; $IDREGEXP = 1605; $IDOK = 1; $IDCANCEL = 2; $IDC_CHECK_DARKMODE_ROUNDEDPOPUPS = 7134
$DEFAULT = 0; $ROUND = 2; $ROUNDSMALL = 3

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][RP]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][RP]::GetWindowText($h, $sb, 256); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][RP]::EnumWindows({ param($h, $l) $p = 0; [void][RP]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	$script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][RP]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids.ToArray()
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][RP]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
# the first visible top-level window of Notepad++ that the filter accepts, waited for up to 5 s
function Wait-Top([scriptblock] $filter) {
	for ($i = 0; $i -lt 50; $i++) {
		$h = Get-Tops | Where-Object { [RP]::IsWindowVisible($_) -and (& $filter $_) } | Select-Object -First 1
		if ($h) { return $h }
		Start-Sleep -Milliseconds 100
	}
	[IntPtr]::Zero
}
function Has-ListBox([IntPtr] $h) { [bool](Get-Kids $h | Where-Object { (Get-Cls $_) -eq 'ListBox' }) }
function Corner([IntPtr] $h) { if ($h -eq [IntPtr]::Zero) { -2 } else { [RP]::Corner($h) } }

$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-rounded-popups-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$file = Join-Path $settings 'lines.txt'
[IO.File]::WriteAllLines($file, [string[]](1..20 | ForEach-Object { "line $_" }))

function Start-Npp {
	$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
	$script:npid = $script:proc.Id; $script:styler = $null; $script:find = $null; $script:darkPage = $null
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 800
}
function Stop-Npp {
	if (-not $script:proc.HasExited) { [void][RP]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
}
# the About box, shown (its window is kept between showings); its corner preference, then hidden again
function About-Corner {
	[void][RP]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_ABOUT, [IntPtr]::Zero)
	$about = Wait-Top { param($h) (Get-Cls $h) -eq '#32770' -and (Get-Txt $h) -eq '' -and -not (Has-ListBox $h) }   # the colour popup has one
	$c = Corner $about
	if ($about -ne [IntPtr]::Zero) { [void](Send $about $WM_COMMAND $IDCANCEL) }
	$c
}
# the colour picker popup of the Style Configurator's foreground colour (a new window each time)
function Colour-Corner {
	if (-not $script:styler) {
		[void][RP]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_LANGSTYLE_CONFIG_DLG, [IntPtr]::Zero)
		$script:styler = Wait-Top { param($h) (Get-Cls $h) -eq '#32770' -and (Get-Txt $h) -eq 'Style Configurator' }
		Start-Sleep -Milliseconds 300
	}
	$picker = [RP]::FindWindowEx($script:styler, [IntPtr]::Zero, 'Button', 'F')
	[void][RP]::PostMessage($picker, $WM_LBUTTONDOWN, [IntPtr]1, [IntPtr]((5 -shl 16) -bor 5))
	$popup = Wait-Top { param($h) (Get-Cls $h) -eq '#32770' -and $h -ne $script:styler -and (Get-Txt $h) -eq '' -and (Has-ListBox $h) }
	Corner $popup
}
# the call tip the Find dialog shows for a zero-length regex match (^)
function CallTip-Corner {
	if (-not $script:find) {
		[void][RP]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_SEARCH_FIND, [IntPtr]::Zero)
		$script:find = Wait-Top { param($h) (Get-Cls $h) -eq '#32770' -and (Get-Txt $h) -eq 'Find' }
		$edit = [RP]::FindWindowEx([RP]::GetDlgItem($script:find, $IDFINDWHAT), [IntPtr]::Zero, 'Edit', $null)
		$r = [IntPtr]::Zero; [void][RP]::SendText($edit, $WM_SETTEXT, [IntPtr]::Zero, '^', 2, 5000, [ref]$r)
		$regex = [RP]::GetDlgItem($script:find, $IDREGEXP)
		[void](Send $regex $BM_SETCHECK 1); [void](Send $script:find $WM_COMMAND $IDREGEXP $regex.ToInt64())
	}
	[void](Send $script:find $WM_COMMAND $IDOK)   # Find Next
	$tip = Wait-Top { param($h) (Get-Cls $h) -eq 'CallTip' }
	Corner $tip
}
function Open-DarkModePage {
	[void][RP]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_SETTING_PREFERENCE, [IntPtr]::Zero)
	$pref = Wait-Top { param($h) (Get-Cls $h) -eq '#32770' -and (Get-Txt $h) -eq 'Preferences' }
	$script:darkPage = Get-Kids $pref | Where-Object { [RP]::GetDlgItem($_, $IDC_CHECK_DARKMODE_ROUNDEDPOPUPS) -ne [IntPtr]::Zero } | Select-Object -First 1
	if (-not $script:darkPage) { $script:darkPage = [IntPtr]::Zero; return [IntPtr]::Zero }   # a build without the option
	[RP]::GetDlgItem($script:darkPage, $IDC_CHECK_DARKMODE_ROUNDEDPOPUPS)
}

try {
	Start-Npp
	Check 'control: the main window is left to Windows (DWMWCP_DEFAULT)' ((Corner $script:main) -eq $DEFAULT) "corner $(Corner $script:main)"

	# on by default
	$c = About-Corner; Check 'default: About box rounded (DWMWCP_ROUND)' ($c -eq $ROUND) "corner $c"
	$c = Colour-Corner; Check 'default: colour picker popup rounded (DWMWCP_ROUND)' ($c -eq $ROUND) "corner $c"
	$c = CallTip-Corner; Check 'default: call tip rounded small (DWMWCP_ROUNDSMALL)' ($c -eq $ROUNDSMALL) "corner $c"
	$box = Open-DarkModePage
	Check 'Preferences > Dark Mode: "Rounded corners on popups" checked and enabled' (($box -ne [IntPtr]::Zero) -and ((Send $box $BM_GETCHECK) -eq 1) -and [RP]::IsWindowEnabled($box))

	# turned off: the popups shown again are square at once
	[void](Send $box $BM_SETCHECK 0)
	[void](Send $script:darkPage $WM_COMMAND $IDC_CHECK_DARKMODE_ROUNDEDPOPUPS $box.ToInt64())   # BN_CLICKED
	$c = About-Corner; Check 'off: About box shown again, square (DWMWCP_DEFAULT)' ($c -eq $DEFAULT) "corner $c"
	$c = Colour-Corner; Check 'off: colour picker popup square' ($c -eq $DEFAULT) "corner $c"
	$c = CallTip-Corner; Check 'off: call tip shown again, square' ($c -eq $DEFAULT) "corner $c"

	# saved, then read back at the next start
	Stop-Npp
	$misc = [regex]::Match([IO.File]::ReadAllText((Join-Path $settings 'config.xml')), '<GUIConfig name="MISC"[^>]*>').Value
	Check 'config.xml: MISC roundedPopups="no"' ($misc -match 'roundedPopups="no"')
	Start-Npp
	$c = About-Corner; Check 'next start: About box square' ($c -eq $DEFAULT) "corner $c"
	$box = Open-DarkModePage
	Check 'next start: the checkbox unchecked' (($box -ne [IntPtr]::Zero) -and ((Send $box $BM_GETCHECK) -eq 0))

	# on again: rounded at once
	[void](Send $box $BM_SETCHECK 1)
	[void](Send $script:darkPage $WM_COMMAND $IDC_CHECK_DARKMODE_ROUNDEDPOPUPS $box.ToInt64())
	$c = About-Corner; Check 'on again: About box rounded' ($c -eq $ROUND) "corner $c"
}
finally {
	Stop-Npp
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notlike 'INFO*' }).Count, $script:fails
}
