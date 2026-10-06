# App-level test (review harness): the rendering mode of Preferences > MISC. applied at once, without restarting
# (branch live-rendering-switch_20261005, kit section 6). Drives the real combo box handler (CB_SETCURSEL, then the
# CBN_SELCHANGE notification a click sends) and reads SCI_GETTECHNOLOGY (0 GDI, 1-4 DirectWrite variants) from every
# Scintilla window of the process: views of Notepad++, of plugins (NPPM_CREATESCINTILLAHANDLE), one a plugin switched
# itself, one destroyed at run time; right-to-left views on GDI in every mode, without a message, switching with the
# tabs; 50 quick switches; the choice saved on exit.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe,
	[string] $TestFile = (Join-Path $PSScriptRoot '..\..\vm\weights.cpp'))
$ErrorActionPreference = 'Stop'
# a build without the live rendering mode switch (upstream, or the right-to-left fix alone) still says to restart
if ([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('graphics issues, restart Notepad++')) {
	'INFO  no live rendering mode switch in this build: skipped'; '0 checks, 0 failed'; exit
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
function Select-Mode([int] $idx) {
	[void][LT.U]::SendMessage($script:combo, $CB_SETCURSEL, [IntPtr]$idx, [IntPtr]::Zero)
	[void](Send-Sync $script:misc $WM_COMMAND $SELCHANGE $script:combo)
	Start-Sleep -Milliseconds 150
}
function Get-Sel { [LT.U]::SendMessage($script:combo, $CB_GETCURSEL, [IntPtr]::Zero, [IntPtr]::Zero).ToInt64() }
# the main and second views: the visible Scintillas whose parent is the Notepad++ window
function Get-MainViews { @(Get-Views | Where-Object { ([LT.U]::GetParent($_) -eq $script:main) -and [LT.U]::IsWindowVisible($_) }) }
# a message box (any dialog but Preferences) shown within the given time
function Wait-AnyBox([int] $tenths = 10) {
	for ($i = 0; $i -lt $tenths; $i++) {
		Start-Sleep -Milliseconds 100
		$b = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [LT.U]::IsWindowVisible($_) -and $_ -ne $script:pref } | Select-Object -First 1
		if ($b) { return $b }
	}
	return $null
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
# the mirrored (right-to-left) views on GDI, the others on the given technology
function Check-Split([string] $name, [int] $expected) {
	$vs = @(Get-Views); $rtl = @($vs | Where-Object { Test-RTL $_ }); $ltr = @($vs | Where-Object { -not (Test-RTL $_) })
	$rt = @($rtl | ForEach-Object { Get-Tech $_ }); $lt = @($ltr | ForEach-Object { Get-Tech $_ })
	$ok = ($rtl.Count -gt 0) -and ($ltr.Count -gt 0) -and (@($rt | Where-Object { $_ -ne 0 }).Count -eq 0) -and (@($lt | Where-Object { $_ -ne $expected }).Count -eq 0)
	Check $name $ok ("RTL views: {0}; LTR views: {1}" -f ($rt -join ','), ($lt -join ','))
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
		$script:pref = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1
		if ($script:pref) { $script:misc = Get-Kids $script:pref | Where-Object { [LT.U]::GetDlgItem($_, $IDC_COMBO_SC_TECHNOLOGY_CHOICE) -ne [IntPtr]::Zero } | Select-Object -First 1 }
	}
	$script:combo = [LT.U]::GetDlgItem($script:misc, $IDC_COMBO_SC_TECHNOLOGY_CHOICE)
	Check 'Preferences > MISC. rendering mode box found' ($script:combo -ne [IntPtr]::Zero)

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

	# right-to-left: DirectWrite ignores the mirroring of the window, so the mirrored views (the document, and the Document
	# Map that follows it) are drawn with GDI in every rendering mode, without a message; the other views follow the switches
	[void][LT.U]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_EDIT_RTL, [IntPtr]::Zero)
	$box = Wait-AnyBox
	Check 'RTL with DirectWrite: no message' ($null -eq $box) $(if ($box) { Get-Txt $box })
	if ($box) { Close-Box $box }
	Check 'RTL with DirectWrite: the document shown is mirrored' (@(Get-MainViews | Where-Object { Test-RTL $_ }).Count -eq 1)
	Check-Split 'RTL with DirectWrite: the mirrored views on GDI, the others on DirectWrite' 1
	foreach ($t in 4, 0, 2, 3, 1) { Select-Mode $t; Check-Split "switch to $t`: the mirrored views keep GDI, the others follow" $t }
	Invoke-Cmd $IDM_EDIT_LTR
	Check-All 'back to LTR: every view on DirectWrite again' 1

	# an RTL document in another tab: its view switches between GDI and the rendering mode with the tabs
	Invoke-Cmd $IDM_FILE_NEW; Invoke-Cmd $IDM_EDIT_RTL
	$v = @(Get-MainViews | Where-Object { Test-RTL $_ })
	Check 'new RTL document: its view mirrored, on GDI' (($v.Count -eq 1) -and ((Get-Tech $v[0]) -eq 0))
	if ($v.Count -eq 1) {
		Invoke-Cmd $IDM_VIEW_TAB1
		Check 'its LTR neighbour tab: the view unmirrored, on DirectWrite' ((-not (Test-RTL $v[0])) -and ((Get-Tech $v[0]) -eq 1))
		Select-Mode 4; Invoke-Cmd $IDM_VIEW_TAB2
		Check 'the RTL tab again, after a switch to DX11: mirrored, on GDI' ((Test-RTL $v[0]) -and ((Get-Tech $v[0]) -eq 0))
		Invoke-Cmd $IDM_VIEW_TAB1
		Check 'its LTR neighbour on DX11' ((-not (Test-RTL $v[0])) -and ((Get-Tech $v[0]) -eq 4))
		Invoke-Cmd $IDM_VIEW_TAB2 # the RTL document stays shown for the quick switches
	}

	# 50 quick switches through every mode, an RTL document shown
	$seq = 0..49 | ForEach-Object { @(0, 1, 2, 3, 4)[$_ % 5] }
	foreach ($t in $seq) { [void][LT.U]::SendMessage($script:combo, $CB_SETCURSEL, [IntPtr]$t, [IntPtr]::Zero); [void](Send-Sync $script:misc $WM_COMMAND $SELCHANGE $script:combo) }
	Start-Sleep -Milliseconds 300
	Check '50 quick switches: still running' (-not $proc.HasExited)
	Check-Split '50 quick switches: the mirrored views on GDI, the others on the last mode' $seq[-1]

	# the choice is saved on exit
	Select-Mode 2
	# no message on exit; a "Save file?" means a document was modified (maybe by input typed into the test window): answered No
	[void][LT.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$boxes = @()
	for ($i = 0; $i -lt 60 -and -not $proc.HasExited; $i++) {
		$b = Wait-AnyBox 2
		if ($b) {
			$boxes += (Get-Txt $b) + ': ' + ((Get-Kids $b | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ')
			$no = [LT.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][LT.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][LT.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
		}
	}
	Check 'exit: no message' ($boxes.Count -eq 0) ($boxes -join '; ')
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
