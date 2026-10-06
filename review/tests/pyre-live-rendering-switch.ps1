# App-level test (review harness), pyre's version of live-rendering-switch.ps1 as written for the pull request's commit
# 305ff13e7: the rendering mode of Preferences > Editing 1 applied at once, without restarting (pyre's
# ScintillaEditView::setTechnologyToAll refuses DirectWrite while the main or second view shows right-to-left text).
# Same checks, except that the box (id 6362) is in Editing 1 and the "Cannot run RTL" warning names Editing 1. A build
# that isn't a Pyre909 build is skipped (0 checks). Drives the real combo box handler (CB_SETCURSEL, then the
# CBN_SELCHANGE notification a click sends) and reads SCI_GETTECHNOLOGY (0 GDI, 1-4 DirectWrite variants) from every
# Scintilla window of the process: views of Notepad++, of plugins (NPPM_CREATESCINTILLAHANDLE), one a plugin switched
# itself, one destroyed at run time; RTL refusal and messages; 50 quick switches; the choice saved on exit.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe,
	[string] $TestFile = (Join-Path $PSScriptRoot '..\..\vm\weights.cpp'))
$ErrorActionPreference = 'Stop'
# a Pyre909 build names itself in its About box (PYRE_BUILD_TAG in AboutDlg.cpp)
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace LT -Name U -MemberDefinition @'
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
$IDC_COMBO_SC_TECHNOLOGY_CHOICE = 6362; $SELCHANGE = [IntPtr]((1 -shl 16) -bor 6362)   # MAKEWPARAM(id, CBN_SELCHANGE)
$NPPM_CREATESCINTILLAHANDLE = 2044; $SCI_SETTECHNOLOGY = 2630; $SCI_GETTECHNOLOGY = 2631
$IDM_SETTING_PREFERENCE = 48011; $IDM_EDIT_RTL = 42026; $IDM_EDIT_LTR = 42027; $IDM_VIEW_DOC_MAP = 44080; $IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002
$IDM_FILE_NEW = 41001; $IDM_VIEW_TAB1 = 44086; $IDM_VIEW_TAB2 = 44087

function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][LT.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(1024); [void][LT.U]::GetWindowText($h, $sb, 1024); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][LT.U]::EnumWindows({ param($h, $l) $p = 0; [void][LT.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	return $script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][LT.U]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	return $script:kids.ToArray()
}
function Get-Views {
	$v = [Collections.Generic.List[IntPtr]]::new()
	foreach ($t in (Get-Tops)) {
		if ((Get-Cls $t) -eq 'Scintilla' -and -not $v.Contains($t)) { $v.Add($t) }
		foreach ($c in (Get-Kids $t)) { if ((Get-Cls $c) -eq 'Scintilla' -and -not $v.Contains($c)) { $v.Add($c) } }
	}
	return $v.ToArray()
}
function Get-Tech([IntPtr] $h) { $r = [IntPtr]::Zero; if ([LT.U]::SendMessageTimeout($h, $SCI_GETTECHNOLOGY, [IntPtr]::Zero, [IntPtr]::Zero, 2, 3000, [ref]$r) -eq [IntPtr]::Zero) { return -9 }; return $r.ToInt64() }
function Test-RTL([IntPtr] $h) { ([LT.U]::GetWindowLong($h, -20) -band 0x00400000) -ne 0 }
function Send-Sync([IntPtr] $h, [int] $msg, [IntPtr] $w, [IntPtr] $l) { $r = [IntPtr]::Zero; [void][LT.U]::SendMessageTimeout($h, $msg, $w, $l, 2, 5000, [ref]$r); $r }
function Invoke-Cmd([int] $id) { [void](Send-Sync $script:main $WM_COMMAND ([IntPtr]$id) ([IntPtr]::Zero)) }
function Select-Mode([int] $idx, [switch] $Async) {
	[void][LT.U]::SendMessage($script:combo, $CB_SETCURSEL, [IntPtr]$idx, [IntPtr]::Zero)
	if ($Async) { [void][LT.U]::PostMessage($script:misc, $WM_COMMAND, $SELCHANGE, $script:combo) } else { [void](Send-Sync $script:misc $WM_COMMAND $SELCHANGE $script:combo) }
	Start-Sleep -Milliseconds 150
}
function Get-Sel { [LT.U]::SendMessage($script:combo, $CB_GETCURSEL, [IntPtr]::Zero, [IntPtr]::Zero).ToInt64() }
# the main and second views: the visible Scintillas whose parent is the Notepad++ window
function Get-MainViews { @(Get-Views | Where-Object { ([LT.U]::GetParent($_) -eq $script:main) -and [LT.U]::IsWindowVisible($_) }) }
function Wait-Box([string] $title, [int] $tenths = 50) {
	for ($i = 0; $i -lt $tenths; $i++) {
		Start-Sleep -Milliseconds 100
		$b = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq $title } | Select-Object -First 1
		if ($b) { $t = (Get-Kids $b | Where-Object { (Get-Cls $_) -eq 'Static' } | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' '; return @($b, $t) }
	}
	return @($null, '')
}
# a message box with only OK closes on WM_CLOSE (its button has the id IDCANCEL, not IDOK)
function Close-Box([IntPtr] $box) {
	[void][LT.U]::PostMessage($box, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	for ($i = 0; $i -lt 30 -and [LT.U]::IsWindow($box); $i++) { Start-Sleep -Milliseconds 100 }
	Check 'message box closed' (-not [LT.U]::IsWindow($box))
}
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Check-All([string] $name, [int] $expected, $except = @()) {
	$vs = @(Get-Views | Where-Object { $except -notcontains $_ }); $ts = @($vs | ForEach-Object { Get-Tech $_ })
	Check $name ((@($ts | Where-Object { $_ -ne $expected }).Count -eq 0) -and $vs.Count -gt 0) ("{0} views: {1}" -f $vs.Count, ($ts -join ','))
}

# a fresh settings folder of its own under the temp folder, so nothing of the user's is touched
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\live-switch-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
Copy-Item $TestFile $settings; $file = Join-Path $settings (Split-Path $TestFile -Leaf)
$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 500
	Invoke-Cmd $IDM_VIEW_CLONE_TO_ANOTHER_VIEW; Invoke-Cmd $IDM_VIEW_DOC_MAP; Start-Sleep -Milliseconds 300

	# views created by plugins through the API; plugin B switches its own view to DirectWrite (draw to GDI DC)
	$pluginA = Send-Sync $script:main $NPPM_CREATESCINTILLAHANDLE ([IntPtr]::Zero) $script:main
	$pluginB = Send-Sync $script:main $NPPM_CREATESCINTILLAHANDLE ([IntPtr]::Zero) $script:main
	[void](Send-Sync $pluginB $SCI_SETTECHNOLOGY ([IntPtr]3) ([IntPtr]::Zero))
	Check-All 'start: every view in DirectWrite (fresh settings default), plugin B aside' 1 @($pluginB)
	Check 'start: plugin B in its own mode' ((Get-Tech $pluginB) -eq 3)

	Invoke-Cmd $IDM_SETTING_PREFERENCE
	for ($i = 0; $i -lt 50 -and -not $script:misc; $i++) {
		Start-Sleep -Milliseconds 100
		$pref = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1
		if ($pref) { $script:misc = Get-Kids $pref | Where-Object { [LT.U]::GetDlgItem($_, $IDC_COMBO_SC_TECHNOLOGY_CHOICE) -ne [IntPtr]::Zero } | Select-Object -First 1 }
	}
	$script:combo = [LT.U]::GetDlgItem($script:misc, $IDC_COMBO_SC_TECHNOLOGY_CHOICE)
	Check 'Preferences > Editing 1 rendering mode box found' ($script:combo -ne [IntPtr]::Zero)

	foreach ($t in 0, 2, 4, 1) {
		Select-Mode $t
		Check-All "switch to $t`: every following view" $t @($pluginB)
		Check "switch to $t`: plugin B left in its own mode" ((Get-Tech $pluginB) -eq 3)
		Check "switch to $t`: box shows it" ((Get-Sel) -eq $t)
	}
	Select-Mode 3; Check-All 'switch to 3 (plugin B''s mode)' 3
	Select-Mode 1; Check-All 'switch to 1: plugin B, now on the previous setting, follows (by design)' 1

	Select-Mode 0
	$pluginC = Send-Sync $script:main $NPPM_CREATESCINTILLAHANDLE ([IntPtr]::Zero) $script:main
	Check 'plugin view created under GDI starts in GDI' ((Get-Tech $pluginC) -eq 0)
	Select-Mode 1; Check 'then follows the switch to DirectWrite' ((Get-Tech $pluginC) -eq 1)

	# a registered view destroyed at run time (WM_CLOSE makes the window destroy itself): the next switches must skip it
	$before = (Get-Views).Count
	[void](Send-Sync $pluginA $WM_CLOSE ([IntPtr]::Zero) ([IntPtr]::Zero)); Start-Sleep -Milliseconds 200
	Check 'plugin view A destroyed' (-not [LT.U]::IsWindow($pluginA)) ("views {0} -> {1}" -f $before, (Get-Views).Count)
	Select-Mode 2; Select-Mode 0; Select-Mode 1
	Check 'switches after a destroyed view: no crash' (-not $proc.HasExited)
	Check-All 'switches after a destroyed view: the others follow' 1

	# right-to-left: allowed with GDI, then DirectWrite is refused with a message and nothing changes
	Select-Mode 0; Invoke-Cmd $IDM_EDIT_RTL
	Check 'RTL with GDI' (@(Get-Views | Where-Object { Test-RTL $_ }).Count -ge 1)
	Select-Mode 1 -Async
	$box, $text = Wait-Box 'Cannot use DirectWrite'
	Check 'refused: message shown' ($null -ne $box)
	Check 'refused: message text' ($text -eq 'DirectWrite cannot display right-to-left text. Please switch the documents shown to left-to-right first (View > Text Direction LTR).') $text
	if ($box) { Close-Box $box }
	Check 'refused: box back to GDI' ((Get-Sel) -eq 0) ("sel " + (Get-Sel))
	Check-All 'refused: no view switched' 0
	Invoke-Cmd $IDM_EDIT_LTR; Select-Mode 1
	Check-All 'after LTR: DirectWrite applies' 1

	# the RTL warning given with DirectWrite on no longer asks to restart
	[void][LT.U]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_EDIT_RTL, [IntPtr]::Zero)
	$box, $text = Wait-Box 'Cannot run RTL'
	Check 'RTL with DirectWrite: warning shown, no restart asked' (($null -ne $box) -and ($text -notmatch 'restart') -and ($text -match 'Editing 1')) $text
	if ($box) { Close-Box $box }
	Check 'RTL with DirectWrite: views stay LTR' (@(Get-Views | Where-Object { Test-RTL $_ }).Count -eq 0)

	# an RTL document in a background tab doesn't block DirectWrite; shown under DirectWrite it is LTR, back to GDI it is RTL again
	Select-Mode 0; Invoke-Cmd $IDM_FILE_NEW; Invoke-Cmd $IDM_EDIT_RTL; Invoke-Cmd $IDM_VIEW_TAB1
	Check 'RTL document in a background tab' (@(Get-MainViews | Where-Object { Test-RTL $_ }).Count -eq 0)
	Select-Mode 1; Check-All 'background RTL document: DirectWrite applies' 1
	[void][LT.U]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_VIEW_TAB2, [IntPtr]::Zero); Start-Sleep -Milliseconds 400
	$box, $text = Wait-Box 'Cannot run RTL' 5; if ($box) { Close-Box $box }
	Check 'RTL document shown under DirectWrite: displayed LTR' (@(Get-MainViews | Where-Object { Test-RTL $_ }).Count -eq 0)
	Select-Mode 0
	Check 'back to GDI: the RTL document shown is RTL again' (@(Get-MainViews | Where-Object { Test-RTL $_ }).Count -eq 1)
	Invoke-Cmd $IDM_VIEW_TAB1
	Check 'its LTR neighbour tab is LTR' (@(Get-MainViews | Where-Object { Test-RTL $_ }).Count -eq 0)

	# 50 quick switches through every mode
	$seq = 0..49 | ForEach-Object { @(0, 1, 2, 3, 4)[$_ % 5] }
	foreach ($t in $seq) { [void][LT.U]::SendMessage($script:combo, $CB_SETCURSEL, [IntPtr]$t, [IntPtr]::Zero); [void](Send-Sync $script:misc $WM_COMMAND $SELCHANGE $script:combo) }
	Start-Sleep -Milliseconds 300
	Check '50 quick switches: still running' (-not $proc.HasExited)
	Check-All '50 quick switches: every view on the last mode' $seq[-1]

	# the choice is saved on exit
	Select-Mode 2
	[void][LT.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$exited = $proc.WaitForExit(15000)
	Check 'Notepad++ closes normally' ($exited -and $proc.ExitCode -eq 0) $(if ($exited) { "exit code $($proc.ExitCode)" } else { 'still running' })
	$cfg = Join-Path $settings 'config.xml'
	$saved = if (Test-Path $cfg) { (Select-String -Path $cfg -Pattern 'writeTechnologyEngine="(\d)"').Matches[0].Groups[1].Value } else { 'none' }
	Check 'config.xml saves the last choice (2)' ($saved -eq '2') "saved $saved"
}
finally {
	if (-not $proc.HasExited) { [void][LT.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
