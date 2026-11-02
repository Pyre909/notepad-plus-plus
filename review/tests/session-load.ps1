# App-level test (review harness): a session of many files loads as saved, and the tabs are found after it. A session of 80
# files in the main view (the 38th active) and 10 in the second view (the 4th active), bookmarks in a few: each file in its
# tab in the session's order, the active tabs, the bookmarks of each file (Notepad++ adds them with the document set in the
# view for a moment, only for the files that have some), and the tab lookups after the session (DocTabView::getIndexByBuffer
# asks only the tab bar whose view references the buffer, looking from the last tab): a tab closed, a file moved to the
# other view. Prints the session's loading time (INFO, -loadingTime).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
Add-Type -Namespace SL -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][SL.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 20000, [ref]$r); $r.ToInt64() }
function Get-Title([IntPtr] $h) { $sb = [Text.StringBuilder]::new(1024); [void][SL.U]::GetWindowText($h, $sb, 1024); $sb.ToString() }
$NPPMSG = 2024; $NPPM_GETNBOPENFILES = $NPPMSG + 7; $NPPM_GETCURRENTDOCINDEX = $NPPMSG + 23; $NPPM_ACTIVATEDOC = $NPPMSG + 28
$SCI_MARKERNEXT = 2047; $MARK_BOOKMARK = 20; $IDM_FILE_CLOSE = 41003; $IDM_VIEW_GOTO_ANOTHER_VIEW = 10001

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\session-load-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$filesDir = Join-Path $root 'files'; New-Item -ItemType Directory -Force $filesDir | Out-Null
$settings = Join-Path $root 'settings'; New-Item -ItemType Directory -Force $settings | Out-Null
$main = foreach ($i in 1..80) { Join-Path $filesDir ('main-{0:D2}.txt' -f $i) }
$sub = foreach ($i in 1..10) { Join-Path $filesDir ('sub-{0:D2}.txt' -f $i) }
# each file a length of its own (its last line), so that the view showing it is the one of that length
$all = @($main) + @($sub); $length = @{}
for ($i = 0; $i -lt $all.Count; $i++) {
	[IO.File]::WriteAllLines($all[$i], [string[]]((1..29 | ForEach-Object { "line $_ of $([IO.Path]::GetFileName($all[$i]))" }) + ('x' * ($i + 1))))
	$length[$all[$i]] = (Get-Item -LiteralPath $all[$i]).Length
}
$marks = @{ $main[4] = @(2, 7); $main[39] = @(11); $main[79] = @(0, 29); $sub[1] = @(5) } # 0-based lines
function File-Xml([string] $f) {
	$x = '<File firstVisibleLine="0" xOffset="0" scrollWidth="1" startPos="0" endPos="0" selMode="0" offset="0" wrapCount="1" lang="None (Normal Text)" encoding="-1" userReadOnly="no" filename="{0}" backupFilePath="" originalFileLastModifTimestamp="0" originalFileLastModifTimestampHigh="0" tabColourId="-1">' -f [Security.SecurityElement]::Escape($f)
	foreach ($l in @($marks[$f])) { if ($null -ne $l) { $x += "<Mark line=`"$l`" />" } }
	$x + '</File>'
}
$xml = '<?xml version="1.0" encoding="UTF-8" ?><NotepadPlus><Session activeView="0"><mainView activeIndex="37">' + (($main | ForEach-Object { File-Xml $_ }) -join '') + '</mainView><subView activeIndex="3">' + (($sub | ForEach-Object { File-Xml $_ }) -join '') + '</subView></Session></NotepadPlus>'
[IO.File]::WriteAllText((Join-Path $settings 'session.xml'), $xml)

$p = Start-Process $Exe -ArgumentList '-multiInst', "-settingsDir=$settings", '-loadingTime', '-titleAdd=REVIEW-TEST' -PassThru
try {
	# the loading time's message box: read, then closed
	$sw = [Diagnostics.Stopwatch]::StartNew(); $text = $null
	while (-not $text -and $sw.Elapsed.TotalSeconds -lt 60) {
		Start-Sleep -Milliseconds 100
		$script:box = [IntPtr]::Zero
		[void][SL.U]::EnumWindows({ param($h, $l) $q = 0; [void][SL.U]::GetWindowThreadProcessId($h, [ref]$q); $c = [Text.StringBuilder]::new(32); [void][SL.U]::GetClassName($h, $c, 32); if ($q -eq $p.Id -and $c.ToString() -eq '#32770' -and [SL.U]::IsWindowVisible($h)) { $script:box = $h }; $true }, [IntPtr]::Zero)
		if ($script:box -ne [IntPtr]::Zero) {
			$script:texts = @(); [void][SL.U]::EnumChildWindows($script:box, { param($h, $l) $script:texts += (Get-Title $h); $true }, [IntPtr]::Zero)
			$text = $script:texts | Where-Object { $_ -match 'session loading' } | Select-Object -First 1
		}
	}
	if ($text -match 'session loading: (\S+)') { $script:results.Add("INFO  session loading: $($Matches[1]) (h:mm:ss)") }
	if ($script:box -ne [IntPtr]::Zero) { [void][SL.U]::PostMessage($script:box, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
	Start-Sleep -Milliseconds 1500
	# the main window by its class: the process's "main window" can be the message box, shown first
	$script:hMain = [IntPtr]::Zero
	[void][SL.U]::EnumWindows({ param($h, $l) $q = 0; [void][SL.U]::GetWindowThreadProcessId($h, [ref]$q); $c = [Text.StringBuilder]::new(32); [void][SL.U]::GetClassName($h, $c, 32); if ($q -eq $p.Id -and $c.ToString() -eq 'Notepad++') { $script:hMain = $h }; $true }, [IntPtr]::Zero)
	$hMain = $script:hMain

	Check 'main view: 80 tabs' ((Send $hMain $NPPM_GETNBOPENFILES 0 1) -eq 80) "$(Send $hMain $NPPM_GETNBOPENFILES 0 1)"
	Check 'second view: 10 tabs' ((Send $hMain $NPPM_GETNBOPENFILES 0 2) -eq 10) "$(Send $hMain $NPPM_GETNBOPENFILES 0 2)"
	Check 'active tabs as saved: the 38th of the main view, the 4th of the second' (((Send $hMain $NPPM_GETCURRENTDOCINDEX 0 0) -eq 37) -and ((Send $hMain $NPPM_GETCURRENTDOCINDEX 0 1) -eq 3)) "main $(Send $hMain $NPPM_GETCURRENTDOCINDEX 0 0), second $(Send $hMain $NPPM_GETCURRENTDOCINDEX 0 1)"

	# each tab: its file (the title bar shows the path) and its bookmarks, read in the view showing it
	$script:sciAll = @()
	[void][SL.U]::EnumChildWindows($hMain, { param($h, $l) $c = [Text.StringBuilder]::new(32); [void][SL.U]::GetClassName($h, $c, 32); if ($c.ToString() -eq 'Scintilla') { $script:sciAll += , $h }; $true }, [IntPtr]::Zero)
	$wrongOrder = @(); $wrongMarks = @()
	foreach ($v in 0, 1) {
		$list = if ($v -eq 0) { $main } else { $sub }
		for ($i = 0; $i -lt $list.Count; $i++) {
			[void](Send $hMain $NPPM_ACTIVATEDOC $v $i)
			if (-not (Get-Title $hMain).Contains($list[$i])) { $wrongOrder += "$v/$i" }
			$sci = $script:sciAll | Where-Object { [SL.U]::IsWindowVisible($_) -and (Send $_ 2006) -eq $length[$list[$i]] } | Select-Object -First 1
			$expected = @($marks[$list[$i]]); $expectedFirst = if ($null -ne $expected[0]) { ($expected | Measure-Object -Minimum).Minimum } else { -1 }
			$first = if ($sci) { Send $sci $SCI_MARKERNEXT 0 (1 -shl $MARK_BOOKMARK) } else { 'no view' }
			$all2 = if ($sci -and $first -ge 0) { @($first) + @(Send $sci $SCI_MARKERNEXT ($first + 1) (1 -shl $MARK_BOOKMARK)) | Where-Object { $_ -ge 0 } } else { @() }
			$expectedAll = @($expected | Where-Object { $null -ne $_ } | Sort-Object)
			if (($first -ne $expectedFirst) -or ((@($all2) -join ',') -ne ($expectedAll -join ','))) { $wrongMarks += "$v/$i (bookmarks $(@($all2) -join ','), expected $($expectedAll -join ','))" }
		}
	}
	Check 'each tab holds its file, in the order of the session' ($wrongOrder.Count -eq 0) $(if ($wrongOrder) { 'wrong: ' + ($wrongOrder -join ', ') } else { '90 tabs' })
	Check 'each file has its bookmarks, the others none' ($wrongMarks.Count -eq 0) $(if ($wrongMarks) { ($wrongMarks | Select-Object -First 5) -join '; ' } else { '4 files with bookmarks' })

	# the tabs found after the session: a tab closed, a file moved to the other view
	[void](Send $hMain $NPPM_ACTIVATEDOC 0 10); [void](Send $hMain 0x0111 $IDM_FILE_CLOSE)
	Check 'a tab closed: 79 left in the main view' ((Send $hMain $NPPM_GETNBOPENFILES 0 1) -eq 79) "$(Send $hMain $NPPM_GETNBOPENFILES 0 1)"
	[void](Send $hMain $NPPM_ACTIVATEDOC 0 20); [void](Send $hMain 0x0111 $IDM_VIEW_GOTO_ANOTHER_VIEW)
	Check 'a file moved to the other view: 78 and 11 tabs' (((Send $hMain $NPPM_GETNBOPENFILES 0 1) -eq 78) -and ((Send $hMain $NPPM_GETNBOPENFILES 0 2) -eq 11)) "main $(Send $hMain $NPPM_GETNBOPENFILES 0 1), second $(Send $hMain $NPPM_GETNBOPENFILES 0 2)"
	[void](Send $hMain $NPPM_ACTIVATEDOC 1 10)
	Check '  it is the last tab of the other view, active there' (((Send $hMain $NPPM_GETCURRENTDOCINDEX 0 1) -eq 10) -and (Get-Title $hMain).Contains($main[21])) "index $(Send $hMain $NPPM_GETCURRENTDOCINDEX 0 1), title has main-22: $((Get-Title $hMain).Contains($main[21]))"
}
finally {
	if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
