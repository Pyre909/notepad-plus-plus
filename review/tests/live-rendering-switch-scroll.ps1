# App-level test (review harness): with right-to-left views drawn with GDI (branch live-rendering-switch_20261005), a
# view switches technology with its tabs: DirectWrite for an LTR document, GDI for an RTL one. Does a long wrapped
# document keep its scroll position through those switches? Checked with the DirectWrite setting (technology changes)
# and with GDI (only the mirroring changes), the long document LTR next to an RTL tab and the other way round.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
# a build without the live rendering mode switch (upstream, or the right-to-left fix alone) still says to restart
if ([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('graphics issues, restart Notepad++')) {
	'INFO  no live rendering mode switch in this build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace LS -Name U -MemberDefinition @'
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
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $CB_SETCURSEL = 0x014E
$IDM_FILE_NEW = 41001; $IDM_EDIT_RTL = 42026; $IDM_EDIT_LTR = 42027; $IDM_VIEW_WRAP = 44022; $IDM_VIEW_TAB1 = 44086; $IDM_VIEW_TAB2 = 44087
$IDM_SETTING_PREFERENCE = 48011
$SCI_GOTOLINE = 2024; $SCI_GETFIRSTVISIBLELINE = 2152; $SCI_VISIBLEFROMDOCLINE = 2220; $SCI_DOCLINEFROMVISIBLE = 2221
$SCI_WRAPCOUNT = 2235; $SCI_SETFIRSTVISIBLELINE = 2613; $SCI_GETTECHNOLOGY = 2631

function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][LS.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][LS.U]::GetWindowText($h, $sb, 256); $sb.ToString() }
function Get-Tops { $script:acc = [Collections.Generic.List[IntPtr]]::new(); [void][LS.U]::EnumWindows({ param($h, $l) $p = 0; [void][LS.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero); $script:acc.ToArray() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][LS.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][LS.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
# a command, then time for the paints that finish restoring a wrapped position (SCN_PAINTED)
function Cmd([int] $id) { [void](Send $script:main $WM_COMMAND $id); Start-Sleep -Milliseconds 700 }
function Test-RTL { ([LS.U]::GetWindowLong($script:view, -20) -band 0x00400000) -ne 0 }
function Set-Direction([bool] $rtl) { if ((Test-RTL) -ne $rtl) { Cmd $(if ($rtl) { $IDM_EDIT_RTL } else { $IDM_EDIT_LTR }) } }
function Get-Top { Send $script:view $SCI_DOCLINEFROMVISIBLE (Send $script:view $SCI_GETFIRSTVISIBLELINE) }
function Get-Tech { Send $script:view $SCI_GETTECHNOLOGY }
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}

# a settings folder of its own, with a long document whose lines wrap
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\live-switch-scroll-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
$long = Join-Path $settings 'long.txt'; $body = ('abcdefghij ' * 30).TrimEnd()
[IO.File]::WriteAllLines($long, [string[]](1..3000 | ForEach-Object { "line $_ $body" }))
$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $long -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	$script:view = Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [LS.U]::IsWindowVisible($_) -and [LS.U]::GetParent($_) -eq $script:main } | Select-Object -First 1
	Cmd $IDM_VIEW_WRAP
	$wraps = Send $script:view $SCI_WRAPCOUNT 1499
	Check 'word wrap on: line 1500 wraps' ($wraps -gt 1) "$wraps lines"
	Cmd $IDM_FILE_NEW # tab 2, a short document

	foreach ($setting in 1, 0) {
		if ($setting -eq 0) { # the GDI setting, through the Preferences box
			Cmd $IDM_SETTING_PREFERENCE
			$pref = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1
			$misc = Get-Kids $pref | Where-Object { [LS.U]::GetDlgItem($_, 6362) -ne [IntPtr]::Zero } | Select-Object -First 1
			$combo = [LS.U]::GetDlgItem($misc, 6362); [void][LS.U]::SendMessage($combo, $CB_SETCURSEL, [IntPtr]0, [IntPtr]::Zero)
			[void](Send $misc $WM_COMMAND ((1 -shl 16) -bor 6362) $combo.ToInt64()); [void][LS.U]::PostMessage($pref, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
			Start-Sleep -Milliseconds 500
		}
		$name = if ($setting) { 'DirectWrite' } else { 'GDI' }
		foreach ($longRTL in $false, $true) {
			Cmd $IDM_VIEW_TAB2; Set-Direction (-not $longRTL); $otherTech = Get-Tech
			Cmd $IDM_VIEW_TAB1; Set-Direction $longRTL
			[void](Send $script:view $SCI_GOTOLINE 1499); [void](Send $script:view $SCI_SETFIRSTVISIBLELINE (Send $script:view $SCI_VISIBLEFROMDOCLINE 1499)); Start-Sleep -Milliseconds 700
			$longTech = Get-Tech; $tops = @()
			foreach ($k in 1..3) { Cmd $IDM_VIEW_TAB2; Cmd $IDM_VIEW_TAB1; $tops += Get-Top }
			$what = "{0}, long document {1}" -f $name, $(if ($longRTL) { 'RTL' } else { 'LTR' })
			# with DirectWrite, the LTR document's view uses it and the RTL one GDI; with GDI, both GDI
			$expectLong = if ($setting -and -not $longRTL) { 1 } else { 0 }; $expectOther = if ($setting -and $longRTL) { 1 } else { 0 }
			Check "${what}: technology $expectLong for it, $expectOther for the other tab" (($longTech -eq $expectLong) -and ($otherTech -eq $expectOther)) "$longTech / $otherTech"
			Check "${what}: still at line 1500 after 3 tab switches" (@($tops | Where-Object { $_ -ne 1499 }).Count -eq 0) ("top lines " + (($tops | ForEach-Object { $_ + 1 }) -join ', '))
		}
	}

	# no message on exit; a "Save file?" means a document was modified (maybe by input typed into the test window): answered No
	[void][LS.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
	$boxes = @()
	for ($i = 0; $i -lt 60 -and -not $proc.HasExited; $i++) {
		Start-Sleep -Milliseconds 250
		foreach ($b in @(Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and [LS.U]::IsWindowVisible($_) })) {
			$boxes += (Get-Txt $b) + ': ' + ((Get-Kids $b | ForEach-Object { Get-Txt $_ } | Where-Object { $_ }) -join ' | ')
			$no = [LS.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][LS.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][LS.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
		}
	}
	Check 'exit: no message' ($boxes.Count -eq 0) ($boxes -join '; ')
	$exited = $proc.WaitForExit(15000)
	Check 'Notepad++ closes normally' ($exited -and $proc.ExitCode -eq 0) $(if ($exited) { "exit code $($proc.ExitCode)" } else { 'still running' })
}
finally {
	if (-not $proc.HasExited) { [void][LS.U]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
