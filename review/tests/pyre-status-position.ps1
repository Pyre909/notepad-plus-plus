# App-level test (review harness), Pyre909 builds only: the status bar's caret position (Preferences > General > Status
# Bar). Col as before without the character grid (tab stops), the cell the caret is in with it (SCI_GETCELLCOLUMN, also on
# a wrapped line's later subline), the character and byte positions beside it when they differ (a tab, an accented letter,
# a CJK character; UTF-16 counted in its own bytes); a selection's bytes; the offset in hex and the line's length when
# chosen, from Preferences (the page's controls) and from config.xml, saved and read back. Read from the status bar's own
# text (SB_GETTEXTW through memory in the process).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace SP -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
[DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, UIntPtr size, uint type, uint protect);
[DllImport("kernel32.dll")] public static extern bool VirtualFreeEx(IntPtr p, IntPtr a, UIntPtr size, uint type);
[DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, UIntPtr size, out UIntPtr read);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc proc, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc proc, IntPtr l);
public static IntPtr FindById(IntPtr parent, int id) {
	IntPtr found = IntPtr.Zero;
	EnumChildWindows(parent, (h, l) => { if (GetDlgCtrlID(h) == id) { found = h; return false; } return true; }, IntPtr.Zero);
	return found;
}
public static IntPtr FindDialog(int pid, string title) {
	IntPtr found = IntPtr.Zero;
	EnumWindows((h, l) => {
		uint p; GetWindowThreadProcessId(h, out p);
		var sb = new System.Text.StringBuilder(256); GetWindowText(h, sb, 256);
		if (p == pid && sb.ToString() == title && IsWindowVisible(h)) { found = h; return false; }
		return true;
	}, IntPtr.Zero);
	return found;
}
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Info([string] $text) { $script:results.Add("INFO  $text") }
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][SP.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }
$IDM_VIEW_CHARACTER_GRID = 44190; $IDM_SETTING_PREFERENCE = 48011

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-status-position-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $root | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
# line 1: a tab; 2: an accented letter (2 bytes); 3: a CJK character (3 bytes); 4: a long line, for wrapping
$text = "AB`tCD`r`nAB" + [char]0xE9 + "CD`r`nAB" + [char]0x4E2D + "CD`r`n" + ('x' * 300) + "`r`n"
$file = Join-Path $root 'positions.txt'; [IO.File]::WriteAllText($file, $text, $utf8)
$file16 = Join-Path $root 'positions-utf16.txt'; [IO.File]::WriteAllText($file16, "AB" + [char]0xE9 + "CD`r`n", [Text.UnicodeEncoding]::new($false, $true))

function Start-Npp([string] $name, [string] $open, [string] $font = 'Consolas') {
	$settings = Join-Path $root $name; New-Item -ItemType Directory -Force $settings | Out-Null
	if (-not (Test-Path (Join-Path $settings 'stylers.xml'))) {
		$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
		$model = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32"[^>]*?fontName=")[^"]*("[^>]*?fontSize=")[^"]*"', "`${1}$font`${2}10`"")
		[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model, $utf8)
	}
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', "`"$open`"" -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	$script:main = $p.MainWindowHandle; $script:settings = $settings; $script:nppPid = $p.Id
	$h = [IntPtr]::Zero; $script:sc = [IntPtr]::Zero
	while (($h = [SP.U]::FindWindowEx($script:main, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($script:sc -eq [IntPtr]::Zero -and [SP.U]::IsWindowVisible($h)) { $script:sc = $h } }
	$script:status = [SP.U]::FindWindowEx($script:main, [IntPtr]::Zero, 'msctls_statusbar32', [NullString]::Value)
	$script:proc = [SP.U]::OpenProcess(0x0438, $false, $p.Id); $script:mem = [SP.U]::VirtualAllocEx($script:proc, [IntPtr]::Zero, [UIntPtr]2048, 0x3000, 4)
	$p
}
function Stop-Npp($p) {
	[void][SP.U]::VirtualFreeEx($script:proc, $script:mem, [UIntPtr]::Zero, 0x8000); [void][SP.U]::CloseHandle($script:proc)
	[void][SP.U]::PostMessage($script:main, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force }
}
# the status bar's caret position part (STATUSBAR_CUR_POS: 2)
function Position-Text {
	$len = (Send $script:status 0x040C 2) -band 0xFFFF # SB_GETTEXTLENGTHW
	[void](Send $script:status 0x040D 2 ([Int64]$script:mem)) # SB_GETTEXTW
	$buf = [byte[]]::new(2 * $len); $r = [UIntPtr]::Zero; [void][SP.U]::ReadProcessMemory($script:proc, $script:mem, $buf, [UIntPtr]$buf.Length, [ref]$r)
	[Text.Encoding]::Unicode.GetString($buf)
}
function Caret-At([int] $line, [int] $offset) { [void](Send $script:sc 2025 ((Send $script:sc 2167 $line) + $offset)); Start-Sleep -Milliseconds 200; Position-Text } # SCI_GOTOPOS
function Has([string] $text, [string[]] $parts) { @($parts | Where-Object { -not $text.Contains($_) }).Count -eq 0 }

try {
	# --- the defaults: Col as before (tab stops), the character and byte positions beside it when they differ
	$p = Start-Npp 'default' $file
	$tab = Caret-At 0 3; $accent = Caret-At 1 4; $plain = Caret-At 0 2
	Check 'default, without the grid: Col to the tab stops, "(ch, byte)" beside it after a tab and an accented letter, none on plain ASCII' ((Has $tab 'Col: 5 (ch 4, byte 4)') -and (Has $accent 'Col: 4 (ch 4, byte 5)') -and (Has $plain 'Col: 3') -and -not $plain.Contains('(ch') -and -not $tab.Contains('Off:') -and -not $tab.Contains('Len:')) "$tab | $accent | $plain"
	[void](Send $script:sc 2160 (Send $script:sc 2167 1) ((Send $script:sc 2167 1) + 4)); Start-Sleep -Milliseconds 200 # SCI_SETSEL: "ABé"
	$sel = Position-Text
	Check '  a selection: its bytes beside its characters when they differ ("ABé": 3 characters, 4 bytes)' (Has $sel 'Sel: 3 (4 bytes) | 1') $sel
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID)
	$tab = Caret-At 0 3; $accent = Caret-At 1 4
	Check 'with the character grid: Col the cell the caret is in (a tab 4 cells), the data positions beside it' ((Has $tab 'Col: 7 (ch 4, byte 4)') -and (Has $accent 'Col: 4 (ch 4, byte 5)')) "$tab | $accent"
	[void](Send $script:sc 2268 1); [void](Send $script:sc 0x0005 0 ((400 -shl 16) -bor 260)); Start-Sleep -Milliseconds 300 # word wrap, a narrow view
	$wrapped = Caret-At 3 250; $subLine = (Send $script:sc 2165 0 ((Send $script:sc 2167 3) + 250)) -gt (Send $script:sc 2165 0 (Send $script:sc 2167 3))
	Check '  on a wrapped line''s later subline: the cell from the line''s start' ((Has $wrapped 'Col: 251') -and $subLine) "$wrapped; on a later subline: $subLine"
	[void](Send $script:sc 2268 0); [void](Send $script:main 0x0005 0 0)

	# --- Preferences > General: the offset in hex and the line's length, chosen on the page
	[void][SP.U]::PostMessage($script:main, 0x0111, [IntPtr]$IDM_SETTING_PREFERENCE, [IntPtr]::Zero); Start-Sleep -Milliseconds 1500
	$prefs = [SP.U]::FindDialog($script:nppPid, 'Preferences')
	$combo = if ($prefs -ne [IntPtr]::Zero) { [SP.U]::FindById($prefs, 6198) } else { [IntPtr]::Zero }
	$check = if ($prefs -ne [IntPtr]::Zero) { [SP.U]::FindById($prefs, 6199) } else { [IntPtr]::Zero }
	Check 'Preferences > General: the caret position''s combo box and the line length check box' (($combo -ne [IntPtr]::Zero) -and ($check -ne [IntPtr]::Zero) -and (Send $combo 0x0146) -eq 3 -and (Send $combo 0x0147) -eq 0) "combo items $(if ($combo -ne [IntPtr]::Zero) { Send $combo 0x0146 }), selected $(if ($combo -ne [IntPtr]::Zero) { Send $combo 0x0147 })"
	if ($combo -ne [IntPtr]::Zero -and $check -ne [IntPtr]::Zero) {
		[void](Send $combo 0x014E 2) # CB_SETCURSEL: column and offset in hex
		[void](Send ([SP.U]::GetParent($combo)) 0x0111 ((1 -shl 16) -bor 6198) ([Int64]$combo)) # CBN_SELCHANGE
		[void](Send $check 0x00F1 1) # BM_SETCHECK
		[void](Send ([SP.U]::GetParent($check)) 0x0111 6199 ([Int64]$check)) # BN_CLICKED
		$both = Caret-At 1 4
		Check '  "Column and offset in hex" and "Line length": the offset (0-based, bytes) and the line''s length, with its bytes' ((Has $both 'Col: 4 (ch 4, byte 5)') -and (Has $both "Off: X'04'") -and (Has $both 'Len: 5 (6 bytes)')) $both
		[void][SP.U]::PostMessage($prefs, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 500
	}
	Stop-Npp $p
	$config = [IO.File]::ReadAllText((Join-Path $script:settings 'config.xml'))
	Check '  saved: config.xml position="both" lineLength="yes"' ($config -match '<GUIConfig name="StatusBar"[^>]*position="both"' -and $config -match '<GUIConfig name="StatusBar"[^>]*lineLength="yes"') ([regex]::Match($config, '<GUIConfig name="StatusBar"[^>]*>').Value)

	# --- the offset alone, set in config.xml; a UTF-16 file counted in its own bytes
	$configPath = Join-Path $script:settings 'config.xml'
	[IO.File]::WriteAllText($configPath, ($config -replace 'position="both"', 'position="hex"'), $utf8)
	$p = Start-Npp 'default' $file
	$hex = Caret-At 1 4
	Check '"Offset in hex" read back: Ln and the offset, no Col' ((Has $hex "Ln: 2    Off: X'04'") -and -not $hex.Contains('Col:')) $hex
	Stop-Npp $p
	[IO.File]::WriteAllText($configPath, ([IO.File]::ReadAllText($configPath) -replace 'position="hex"', 'position="both"'), $utf8)
	$p = Start-Npp 'default' $file16
	$wide = Caret-At 0 4
	Check 'a UTF-16 file: the bytes of UTF-16 (2 a character here), not of the UTF-8 held inside' ((Has $wide 'Col: 4 (ch 4, byte 7)') -and (Has $wide "Off: X'06'") -and (Has $wide 'Len: 5 (10 bytes)')) $wide
	Stop-Npp $p
	# a noncharacter (U+FFFF: EF BF BF), which Scintilla takes as 3 invalid bytes: counted as Scintilla counts it (2026-11-10:
	# the status bar's one-pass count leaves it to Scintilla)
	$fileNonChar = Join-Path $root 'nonchar.txt'; [IO.File]::WriteAllBytes($fileNonChar, [byte[]](0xEF, 0xBB, 0xBF, 0x61, 0xEF, 0xBF, 0xBF, 0x62, 0x0D, 0x0A))
	$p = Start-Npp 'default' $fileNonChar
	$nonChar = Caret-At 0 5
	Check 'U+FFFF (a noncharacter): its 3 bytes 3 characters, as Scintilla counts them ("a", U+FFFF, "b": ch 6, byte 6, Len 5)' ((Has $nonChar '(ch 6, byte 6)') -and (Has $nonChar 'Len: 5') -and -not $nonChar.Contains('Len: 5 (')) $nonChar
	Stop-Npp $p

	# --- a CJK character in a 2:1 font, with the grid: two cells, three bytes
	if ([Drawing.Text.InstalledFontCollection]::new().Families.Name -contains 'BIZ UDGothic') {
		$p = Start-Npp 'biz' $file 'BIZ UDGothic'
		if ((Send $script:sc 5104) -eq 0) { [void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) }
		$cjk = Caret-At 2 5
		Check 'BIZ UDGothic, the grid: after a CJK character Col counts its two cells, the data positions its one character and three bytes' (Has $cjk 'Col: 5 (ch 4, byte 6)') $cjk
		Stop-Npp $p
	}
	else { Info 'BIZ UDGothic not installed: the CJK check skipped' }
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
