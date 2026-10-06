# App-level test (review harness): right-to-left views drawn with GDI (branch rtl-views-gdi_20261006). Notepad++ shows
# RTL by mirroring the Scintilla window (WS_EX_LAYOUTRTL), and only GDI follows the mirroring: a mirrored view is drawn
# with GDI whatever the rendering mode, and gets the rendering mode back once LTR, without a message. With fresh settings
# (DirectWrite): the document's view, the Document Map, a clone in the other view, tabs switching the view's technology,
# and a long wrapped document keeping its scroll position through those switches. Needs no live rendering mode switch.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
Add-Type -Namespace RG -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int idx);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111
$IDM_FILE_NEW = 41001; $IDM_EDIT_RTL = 42026; $IDM_EDIT_LTR = 42027; $IDM_VIEW_WRAP = 44022; $IDM_VIEW_DOC_MAP = 44080
$IDM_VIEW_TAB1 = 44086; $IDM_VIEW_TAB2 = 44087; $IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002
$SCI_GOTOLINE = 2024; $SCI_GETFIRSTVISIBLELINE = 2152; $SCI_VISIBLEFROMDOCLINE = 2220; $SCI_DOCLINEFROMVISIBLE = 2221
$SCI_WRAPCOUNT = 2235; $SCI_SETFIRSTVISIBLELINE = 2613; $SCI_GETTECHNOLOGY = 2631

function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][RG.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(512); [void][RG.U]::GetWindowText($h, $sb, 512); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][RG.U]::EnumWindows({ param($h, $l) $p = 0; [void][RG.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][RG.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Get-Views { $v = [Collections.Generic.List[IntPtr]]::new(); foreach ($t in (Get-Tops)) { if ((Get-Cls $t) -eq 'Scintilla') { $v.Add($t) }; foreach ($c in (Get-Kids $t)) { if ((Get-Cls $c) -eq 'Scintilla' -and -not $v.Contains($c)) { $v.Add($c) } } }; $v.ToArray() }
# the main and second views: the visible Scintillas whose parent is the Notepad++ window
function Get-MainViews { @(Get-Views | Where-Object { ([RG.U]::GetParent($_) -eq $script:main) -and [RG.U]::IsWindowVisible($_) }) }
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][RG.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
# a command, then time for the paints that finish restoring a wrapped position (SCN_PAINTED)
function Cmd([int] $id) { [void](Send $script:main $WM_COMMAND $id); Start-Sleep -Milliseconds 500 }
function Get-Tech([IntPtr] $h) { Send $h $SCI_GETTECHNOLOGY }
function Test-RTL([IntPtr] $h) { ([RG.U]::GetWindowLong($h, -20) -band 0x00400000) -ne 0 }
function Set-Direction([IntPtr] $h, [bool] $rtl) { if ((Test-RTL $h) -ne $rtl) { Cmd $(if ($rtl) { $IDM_EDIT_RTL } else { $IDM_EDIT_LTR }) } }
function Get-Top([IntPtr] $h) { Send $h $SCI_DOCLINEFROMVISIBLE (Send $h $SCI_GETFIRSTVISIBLELINE) }
function Describe([IntPtr] $h) { '{0}, technology {1}' -f $(if (Test-RTL $h) { 'RTL' } else { 'LTR' }), (Get-Tech $h) }
# a message box shown within the given time (its title and texts)
function Wait-AnyBox([int] $tenths = 10) {
	for ($i = 0; $i -lt $tenths; $i++) {
		Start-Sleep -Milliseconds 100
		$b = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [RG.U]::IsWindowVisible($_) } | Select-Object -First 1
		if ($b) { return $b }
	}
	$null
}
function Close-AnyBox([IntPtr] $b) { $no = [RG.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][RG.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][RG.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) } }
function Box-Text([IntPtr] $b) { (Get-Txt $b) + ': ' + ((Get-Kids $b | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ') }
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
# the mirrored views on GDI, the others on DirectWrite (1)
function Check-Split([string] $name) {
	$vs = @(Get-Views); $bad = @($vs | Where-Object { (Get-Tech $_) -ne $(if (Test-RTL $_) { 0 } else { 1 }) })
	Check $name (($bad.Count -eq 0) -and ($vs.Count -gt 0)) ("{0} views: {1}" -f $vs.Count, (($vs | ForEach-Object { Describe $_ }) -join '; '))
}

# a settings folder of its own, with a long document whose lines wrap
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\rtl-views-gdi-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$long = Join-Path $settings 'long.txt'; $body = ('abcdefghij ' * 30).TrimEnd()
[IO.File]::WriteAllLines($long, [string[]](1..3000 | ForEach-Object { "line $_ $body" }))
$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $long -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	$view = @(Get-MainViews)[0]
	Check 'start: the document LTR, on DirectWrite (fresh settings default)' ((-not (Test-RTL $view)) -and ((Get-Tech $view) -eq 1)) (Describe $view)
	$before = @(Get-Views); Cmd $IDM_VIEW_DOC_MAP; $map = @(Get-Views | Where-Object { $before -notcontains $_ })[0]
	Check 'Document Map shown: LTR, on DirectWrite' (($null -ne $map) -and (-not (Test-RTL $map)) -and ((Get-Tech $map) -eq 1)) $(if ($map) { Describe $map } else { 'not found' })

	# View > Text Direction RTL with DirectWrite on: allowed, without a message; the view, and the map that follows it, on GDI
	[void][RG.U]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_EDIT_RTL, [IntPtr]::Zero)
	$box = Wait-AnyBox
	Check 'RTL with DirectWrite: no message' ($null -eq $box) $(if ($box) { Box-Text $box })
	if ($box) { Close-AnyBox $box; Start-Sleep -Milliseconds 300 }
	Check 'RTL: the view mirrored, on GDI' ((Test-RTL $view) -and ((Get-Tech $view) -eq 0)) (Describe $view)
	Check 'RTL: the Document Map mirrored, on GDI' (($null -ne $map) -and (Test-RTL $map) -and ((Get-Tech $map) -eq 0)) $(if ($map) { Describe $map })
	Check-Split 'RTL: every mirrored view on GDI, the others on DirectWrite'
	Cmd $IDM_EDIT_LTR
	Check 'LTR again: the view and the map back on DirectWrite' ((-not (Test-RTL $view)) -and ((Get-Tech $view) -eq 1) -and ($null -ne $map) -and (-not (Test-RTL $map)) -and ((Get-Tech $map) -eq 1))

	# a long wrapped document keeps its scroll position while its view switches technology with the tabs
	Cmd $IDM_VIEW_WRAP
	$wraps = Send $view $SCI_WRAPCOUNT 1499
	Check 'word wrap on: line 1500 wraps' ($wraps -gt 1) "$wraps lines"
	Cmd $IDM_FILE_NEW; Cmd $IDM_EDIT_RTL
	Check 'new RTL document (tab 2): its view mirrored, on GDI' ((Test-RTL $view) -and ((Get-Tech $view) -eq 0)) (Describe $view)
	foreach ($longRTL in $false, $true) {
		Cmd $IDM_VIEW_TAB2; Set-Direction $view (-not $longRTL)
		Cmd $IDM_VIEW_TAB1; Set-Direction $view $longRTL
		[void](Send $view $SCI_GOTOLINE 1499); [void](Send $view $SCI_SETFIRSTVISIBLELINE (Send $view $SCI_VISIBLEFROMDOCLINE 1499)); Start-Sleep -Milliseconds 600
		$longTech = Get-Tech $view; $tops = @(); $otherTechs = @()
		foreach ($k in 1..3) { Cmd $IDM_VIEW_TAB2; $otherTechs += Get-Tech $view; Cmd $IDM_VIEW_TAB1; $tops += Get-Top $view }
		$what = "long document {0}, the other tab {1}" -f $(if ($longRTL) { 'RTL' } else { 'LTR' }), $(if ($longRTL) { 'LTR' } else { 'RTL' })
		$expectLong = if ($longRTL) { 0 } else { 1 }; $expectOther = if ($longRTL) { 1 } else { 0 }
		Check "${what}: the view on $expectLong for it, $expectOther for the other tab" (($longTech -eq $expectLong) -and (@($otherTechs | Where-Object { $_ -ne $expectOther }).Count -eq 0)) ("$longTech / " + ($otherTechs -join ','))
		Check "${what}: still at line 1500 after 3 tab switches" (@($tops | Where-Object { $_ -ne 1499 }).Count -eq 0) ("top lines " + (($tops | ForEach-Object { $_ + 1 }) -join ', '))
	}

	# the RTL long document cloned into the second view: mirrored there too, on GDI
	Cmd $IDM_VIEW_CLONE_TO_ANOTHER_VIEW
	$mv = @(Get-MainViews)
	Check 'RTL document cloned to the other view: both views mirrored, on GDI' (($mv.Count -eq 2) -and (@($mv | Where-Object { -not (Test-RTL $_) -or ((Get-Tech $_) -ne 0) }).Count -eq 0)) (($mv | ForEach-Object { Describe $_ }) -join '; ')

	# no message on exit; a "Save file?" means a document was modified (maybe by input typed into the test window): answered No
	[void][RG.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$boxes = @()
	for ($i = 0; $i -lt 60 -and -not $proc.HasExited; $i++) { $b = Wait-AnyBox 2; if ($b) { $boxes += Box-Text $b; Close-AnyBox $b } }
	Check 'exit: no message' ($boxes.Count -eq 0) ($boxes -join '; ')
	$exited = $proc.WaitForExit(15000)
	Check 'Notepad++ closes normally' ($exited -and $proc.ExitCode -eq 0) $(if ($exited) { "exit code $($proc.ExitCode)" } else { 'still running' })
}
finally {
	if (-not $proc.HasExited) { [void][RG.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
