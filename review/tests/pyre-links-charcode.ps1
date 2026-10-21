# App-level test (review harness), Pyre909 builds only: (1) the status bar's position part shows the code of the character
# after the caret (U+0061, U+00E9, U+20AC, U+1F600, U+000D for a line end, 0xE9 for an invalid UTF-8 byte, the code point
# of an ANSI document's byte, nothing at the end or with a selection) in a part wide enough (320 px at 96 DPI, the
# longest English text fitting); (2) with
# Preferences > Cloud & Link > "Open with Ctrl+click" (config.xml <GUIConfig name="URL" ctrlClick="yes">), a Ctrl+click
# on a link opens it without adding a caret, a Ctrl+double-click opens it once, Ctrl+clicks on two links in a row open
# both, a Ctrl+click on a selected link is Scintilla's (no opening), a double-click selects a word; with it off
# (the default), as upstream: a Ctrl+click adds a caret, a double-click opens the link. The link is a file:/// URL of a
# script of the test (opened.cmd): each opening runs it, and it adds a line to opened.log; no browser or Explorer
# window is involved.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
# a Pyre909 build names itself in its About box (PYRE_BUILD_TAG in AboutDlg.cpp)
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -Namespace LC -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetDoubleClickTime();
[DllImport("kernel32.dll")] public static extern uint GetACP();
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
[DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, UIntPtr size, uint type, uint protect);
[DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr h, IntPtr addr, UIntPtr size, uint type);
[DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr read);
[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
// a message whose lParam is a buffer: one allocated in the window's process, read back
public static byte[] Remote(IntPtr h, uint pid, uint msg, IntPtr w, int size) {
  IntPtr proc = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid);
  byte[] buf = new byte[size];
  if (proc == IntPtr.Zero) return buf;
  IntPtr mem = VirtualAllocEx(proc, IntPtr.Zero, (UIntPtr)size, 0x3000, 0x04);
  if (mem != IntPtr.Zero) {
    IntPtr r; UIntPtr n;
    SendMessageTimeout(h, msg, w, mem, 2, 3000, out r);
    ReadProcessMemory(proc, mem, buf, (UIntPtr)size, out n);
    VirtualFreeEx(proc, mem, UIntPtr.Zero, 0x8000);
  }
  CloseHandle(proc);
  return buf;
}
'@
# per-monitor aware: Windows scales the coordinates of the clicks a DPI-unaware process posts (x1.5 at 144 DPI)
[void][LC.U]::SetThreadDpiAwarenessContext([IntPtr](-4))
$WM_CLOSE = 0x0010; $WM_LBUTTONDOWN = 0x0201; $WM_LBUTTONUP = 0x0202; $MK_LBUTTON = 1; $MK_CONTROL = 8
$SB_GETPARTS = 0x0406; $SB_GETTEXTW = 0x040D; $STATUSBAR_CUR_POS = 2
$SCI_GOTOPOS = 2025; $SCI_SETSEL = 2160; $SCI_GETCURRENTPOS = 2008; $SCI_GETSELECTIONS = 2570; $SCI_GETSELTEXT = 2161
$SCI_GETSELECTIONSTART = 2143; $SCI_GETSELECTIONEND = 2145; $SCI_POINTXFROMPOSITION = 2164; $SCI_POINTYFROMPOSITION = 2165
$SCI_TEXTHEIGHT = 2279; $SCI_INDICATORVALUEAT = 2507; $SCI_GETLENGTH = 2006; $URL_INDIC = 8

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][LC.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][LC.U]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Title([IntPtr] $h) { $sb = [Text.StringBuilder]::new(260); [void][LC.U]::GetWindowText($h, $sb, 260); $sb.ToString() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][LC.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Get-Tops { $script:tops = [Collections.Generic.List[IntPtr]]::new(); [void][LC.U]::EnumWindows({ param($h, $l) $script:tops.Add($h); $true }, [IntPtr]::Zero); $script:tops.ToArray() }
function Get-View($p) { Get-Kids $p.MainWindowHandle | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [LC.U]::IsWindowVisible($_) -and [LC.U]::GetParent($_) -eq $p.MainWindowHandle } | Select-Object -First 1 }
function Get-StatusBar($p) { Get-Kids $p.MainWindowHandle | Where-Object { (Get-Cls $_) -eq 'msctls_statusbar32' } | Select-Object -First 1 }

function Start-Npp([string] $settings, [string[]] $files = @()) {
	$p = Start-Process $Exe -ArgumentList (@('-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST') + ($files | ForEach-Object { "`"$_`"" })) -PassThru
	for ($i = 0; $i -lt 150; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh(); if (($p.MainWindowHandle -ne 0) -and (Get-View $p)) { break } }
	Start-Sleep -Milliseconds 1200
	$p
}
function Stop-Npp($p) {
	if (-not $p.HasExited) {
		[void][LC.U]::PostMessage($p.MainWindowHandle, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
		if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force }
	}
}
# the text of the status bar's position part (Ln, Col, Pos and the character's code)
function Get-PosText($p) {
	$sb = Get-StatusBar $p
	$bytes = [LC.U]::Remote($sb, [uint32]$p.Id, $SB_GETTEXTW, [IntPtr]$STATUSBAR_CUR_POS, 1024)
	$s = [Text.Encoding]::Unicode.GetString($bytes); $s.Substring(0, [Math]::Max(0, $s.IndexOf([char]0)))
}
function Move-Caret($p, [IntPtr] $view, [long] $pos) { [void](Send $view $SCI_GOTOPOS $pos); Start-Sleep -Milliseconds 250; Get-PosText $p }
function Get-Code([string] $text) { if ($text -match '\s(U\+[0-9A-F]{4,6}|0x[0-9A-F]{2})$') { $Matches[1] } else { '(none)' } }

# the openings of the link so far (lines of opened.log), and the new ones after a click (up to 6 s for the first)
function Get-OpenCount { $n = 0; foreach ($log in (Get-ChildItem -LiteralPath (Split-Path $script:openLog) -Filter 'opened*.log')) { $n += @(Get-Content -LiteralPath $log.FullName).Count }; $n }
function Wait-Opened([int] $before) { for ($i = 0; $i -lt 30; $i++) { if ((Get-OpenCount) -gt $before) { Start-Sleep -Milliseconds 1500; break }; Start-Sleep -Milliseconds 200 }; (Get-OpenCount) - $before }
# a click at a position of the view (lParam: client coordinates), with Ctrl or not; two for a double-click
function Click-At([IntPtr] $view, [long] $pos, [bool] $ctrl, [int] $count = 1) {
	$x = (Send $view $SCI_POINTXFROMPOSITION 0 $pos) + 3
	$y = (Send $view $SCI_POINTYFROMPOSITION 0 $pos) + [int]((Send $view $SCI_TEXTHEIGHT 0) / 2)
	$lp = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
	$keys = $(if ($ctrl) { $MK_CONTROL } else { 0 })
	for ($i = 0; $i -lt $count; $i++) {
		[void][LC.U]::PostMessage($view, $WM_LBUTTONDOWN, [IntPtr]($MK_LBUTTON -bor $keys), $lp)
		[void][LC.U]::PostMessage($view, $WM_LBUTTONUP, [IntPtr]$keys, $lp)
	}
	Start-Sleep -Milliseconds 400
}

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-links-charcode-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:openLog = ''
try {
	New-Item -ItemType Directory -Force $root | Out-Null
	$root = (Get-Item -LiteralPath $root).FullName # the long name (GetTempPath may give an 8.3 one)
	$target = Join-Path $root 'opened.cmd'; $script:openLog = Join-Path $root 'opened.log'
	[IO.File]::WriteAllText($target, "@echo off`r`necho opened>>""%~dp0opened.log""`r`n")
	# a second link, its own script and log: two scripts appending to one file at once can lose a line
	$target2 = Join-Path $root 'opened2.cmd'; $url2 = 'file:///' + ($target2 -replace '\\', '/')
	[IO.File]::WriteAllText($target2, "@echo off`r`necho opened>>""%~dp0opened2.log""`r`n")
	$url = 'file:///' + ($target -replace '\\', '/')

	# --- the character after the caret
	$utf8 = Join-Path $root 'chars-utf8.txt'
	$bytes = [Collections.Generic.List[byte]]::new()
	$bytes.AddRange([byte[]](0xEF, 0xBB, 0xBF)) # BOM: loaded as UTF-8 whatever the bytes
	$bytes.AddRange([Text.Encoding]::UTF8.GetBytes("a" + [char]0xE9 + [char]0x20AC + [char]::ConvertFromUtf32(0x1F600) + "`r`nx"))
	$bytes.Add(0xE9) # invalid in UTF-8
	[IO.File]::WriteAllBytes($utf8, $bytes.ToArray())
	$ansi = Join-Path $root 'chars-ansi.txt'
	[IO.File]::WriteAllBytes($ansi, [byte[]](0x63, 0x61, 0x66, 0xE9, 0x0D, 0x0A)) # "café" in Windows-1252, no BOM
	$links = Join-Path $root 'links.txt'
	[IO.File]::WriteAllText($links, "see $url here`r`nsecond line`r`nalso $url2 there`r`n", [Text.UTF8Encoding]::new($false))

	$settings = Join-Path $root 'settings'; New-Item -ItemType Directory -Force $settings | Out-Null
	$proc = Start-Npp $settings @($utf8)
	$view = Get-View $proc
	$sb = Get-StatusBar $proc
	$dpi = [LC.U]::GetDpiForWindow($proc.MainWindowHandle)
	$parts = [LC.U]::Remote($sb, [uint32]$proc.Id, $SB_GETPARTS, [IntPtr]6, 24)
	$right = 0..5 | ForEach-Object { [BitConverter]::ToInt32($parts, $_ * 4) }
	$posWidth = $right[2] - $right[1]
	Check 'the position part: 320 px at 96 DPI' ([Math]::Abs($posWidth - [Math]::Round(320 * $dpi / 96)) -le 1) "$posWidth px at $dpi DPI"
	# the longest English text of a 12 MB file, in the status bar's Segoe UI 9 pt (12 px at 96 DPI), with the part's margins
	Add-Type -AssemblyName System.Windows.Forms, System.Drawing
	$longest = 'Ln: 123,456    Col: 1,234    Pos: 12,345,678    U+1F600'
	$font = [Drawing.Font]::new('Segoe UI', 12, [Drawing.GraphicsUnit]::Pixel)
	$needed = [Math]::Ceiling(([Windows.Forms.TextRenderer]::MeasureText($longest, $font).Width + 8) * $dpi / 96)
	Check '  it fits the longest English text with a code' ($needed -le $posWidth) "$needed px needed of $posWidth"

	$want = @('0=U+0061', '1=U+00E9', '3=U+20AC', '6=U+1F600', '10=U+000D', '12=U+0078', '13=0xE9')
	$seen = foreach ($w in $want) { $pos = [int]($w -split '=')[0]; $t = Move-Caret $proc $view $pos; "{0}={1}" -f $pos, (Get-Code $t) }
	Check 'UTF-8: a, é, €, 😀 (4 bytes), a line end, x, an invalid byte' (($seen -join ' ') -eq ($want -join ' ')) ($seen -join ' ')
	$t = Move-Caret $proc $view (Send $view $SCI_GETLENGTH)
	Check '  at the end of the document: no code' ((Get-Code $t) -eq '(none)') $t
	[void](Send $view $SCI_SETSEL 1 3); Start-Sleep -Milliseconds 250; $t = Get-PosText $proc
	Check '  a selection: Sel, no code' (($t -match 'Sel') -and ((Get-Code $t) -eq '(none)')) $t
	$t = Move-Caret $proc $view 6
	Check '  the text: Ln, Col, Pos and the code' ($t -match '^Ln: 1\s+Col: \d+\s+Pos: 7\s+U\+1F600$') $t
	Stop-Npp $proc

	$proc = Start-Npp $settings @($ansi)
	$view = Get-View $proc
	$t = Move-Caret $proc $view 3
	if ([LC.U]::GetACP() -eq 1252) { Check 'ANSI document: é (byte 0xE9) shown as U+00E9' ((Get-Code $t) -eq 'U+00E9') $t }
	else { $script:results.Add("INFO  ANSI check skipped: the system code page is $([LC.U]::GetACP()), not 1252") }
	Stop-Npp $proc

	# --- links: "Open with Ctrl+click" off (the default, upstream's behaviour)
	$configPath = Join-Path $settings 'config.xml'
	$url0 = (Select-String -Path $configPath -Pattern '<GUIConfig name="URL"[^>]*>' | Select-Object -First 1).Matches[0].Value
	Check 'config.xml: ctrlClick="no" by default' ($url0 -match 'ctrlClick="no"') $url0
	$linkPos = 6 # in "see file:///..."
	$proc = Start-Npp $settings @($links)
	$view = Get-View $proc
	Check '  the link has its indicator' ((Send $view $SCI_INDICATORVALUEAT $URL_INDIC $linkPos) -ne 0) $url
	$n = Get-OpenCount; [void](Send $view $SCI_GOTOPOS 0); Click-At $view $linkPos $true; Start-Sleep -Milliseconds 1500
	$opened = (Get-OpenCount) - $n
	$sels = Send $view $SCI_GETSELECTIONS
	Check 'off: Ctrl+click on the link adds a caret, opens nothing' (($opened -eq 0) -and ($sels -eq 2)) "selections $sels, opened $opened"
	$n = Get-OpenCount; [void](Send $view $SCI_GOTOPOS 0); Click-At $view ($linkPos + 2) $false 2
	$opened = Wait-Opened $n
	Check 'off: a double-click opens it (once)' ($opened -eq 1) "opened $opened"
	Stop-Npp $proc

	# --- "Open with Ctrl+click" on
	$config = [IO.File]::ReadAllText($configPath) -replace 'ctrlClick="no"', 'ctrlClick="yes"'
	[IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))
	$proc = Start-Npp $settings @($links)
	$view = Get-View $proc
	$n = Get-OpenCount; [void](Send $view $SCI_GOTOPOS 0); Click-At $view $linkPos $true
	$opened = Wait-Opened $n
	$sels = Send $view $SCI_GETSELECTIONS; $caret = Send $view $SCI_GETCURRENTPOS
	Check 'on: Ctrl+click opens the link, no caret added, the caret where it was' (($opened -eq 1) -and ($sels -eq 1) -and ($caret -eq 0)) "opened $opened, selections $sels, caret $caret"
	Start-Sleep -Milliseconds ([LC.U]::GetDoubleClickTime() + 100)
	$n = Get-OpenCount; Click-At $view $linkPos $true 2
	$opened = Wait-Opened $n
	Check '  a Ctrl+double-click opens it once' ($opened -eq 1) "opened $opened"
	Start-Sleep -Milliseconds ([LC.U]::GetDoubleClickTime() + 100)
	# Ctrl+clicks on two links in a row (within the double-click time, lines apart): both open
	Start-Sleep -Milliseconds ([LC.U]::GetDoubleClickTime() + 100)
	$link2Pos = (Send $view 2167 2) + 6 # SCI_POSITIONFROMLINE: "also file:///..." on line 3
	$n = Get-OpenCount; Click-At $view $linkPos $true; Click-At $view $link2Pos $true
	$opened = Wait-Opened $n; Start-Sleep -Milliseconds 1000; $opened = (Get-OpenCount) - $n
	Check '  Ctrl+clicks on two links in a row open both' ($opened -eq 2) "opened $opened"
	# a Ctrl+click on a selected link: Scintilla's (a drag of the selection, or its caret), nothing opened
	Start-Sleep -Milliseconds ([LC.U]::GetDoubleClickTime() + 100)
	[void](Send $view $SCI_SETSEL 4 ($linkPos + 10))
	$n = Get-OpenCount; Click-At $view $linkPos $true; Start-Sleep -Milliseconds 1500
	$opened = (Get-OpenCount) - $n
	Check '  a Ctrl+click on a selected link is Scintilla''s: nothing opened' ($opened -eq 0) "opened $opened"
	Start-Sleep -Milliseconds ([LC.U]::GetDoubleClickTime() + 100)
	$n = Get-OpenCount; Click-At $view ($linkPos + 2) $false 2
	Start-Sleep -Milliseconds 2500
	$opened = (Get-OpenCount) - $n
	$selLen = (Send $view $SCI_GETSELECTIONEND) - (Send $view $SCI_GETSELECTIONSTART)
	Check '  a double-click selects a word, opens nothing' (($opened -eq 0) -and ($selLen -gt 0)) "opened $opened, selection $selLen chars"
	Click-At $view 0 $true # Ctrl+click on plain text: a caret added, as upstream
	$sels = Send $view $SCI_GETSELECTIONS
	Check '  Ctrl+click on plain text still adds a caret' ($sels -eq 2) "selections $sels"
	Stop-Npp $proc
	$url1 = (Select-String -Path $configPath -Pattern '<GUIConfig name="URL"[^>]*>' | Select-Object -First 1).Matches[0].Value
	Check '  saved: ctrlClick="yes"' ($url1 -match 'ctrlClick="yes"') $url1
}
finally {
	foreach ($p in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $p.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
