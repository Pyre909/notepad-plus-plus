# App-level test (review harness), Pyre909 builds only: the indentation guides and the caret line's number (2026-11-10).
# Preferences > Margins/Border/Edge > Indent Guides (config.xml indentGuideStyle): "Solid, the caret's block highlighted"
# by default, Solid, Dotted (upstream's). The guide of the caret's block found from the lines' indentation (pyre's
# SCI_UPDATEACTIVEINDENTGUIDE, read back with SCI_GETACTIVEINDENTGUIDE) as the caret moves: on a body line, a line a block
# hangs from, a blank line, a nested block, a top-level line, C++ with tabs and braces. The Global Styles "Current line
# number" and "Active indent guideline" (a theme without them: the text's colour and the line numbers'). Pixels, with
# DirectWrite and GDI: the guides solid (every row of a line) or dotted (one in two), the caret block's guide in its colour
# and no other, the caret line's number in its colour and, once the caret is on another line, only there (the margin
# drawn again). Chosen in Preferences, applied at once, saved and read back. The block's update in a block of 200,000
# lines (its cost: INFO; beyond 10,000 lines out of the view, no highlight).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace IG -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc proc, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc proc, IntPtr l);
public static IntPtr FindById(IntPtr parent, int id) {
	IntPtr found = IntPtr.Zero;
	EnumChildWindows(parent, (h, l) => { if (GetDlgCtrlID(h) == id) { found = h; return false; } return true; }, IntPtr.Zero);
	return found;
}
public static IntPtr FindDialog(int processId, string title) {
	IntPtr found = IntPtr.Zero;
	EnumWindows((h, l) => {
		uint p; GetWindowThreadProcessId(h, out p);
		var sb = new System.Text.StringBuilder(256); GetWindowText(h, sb, 256);
		if (p == processId && sb.ToString() == title && IsWindowVisible(h)) { found = h; return false; }
		return true;
	}, IntPtr.Zero);
	return found;
}
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
'@
[void][IG.U]::SetThreadDpiAwarenessContext([IntPtr](-4)) # per-monitor v2: rectangles in the pixels PrintWindow draws
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Info([string] $text) { $script:results.Add("INFO  $text") }
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][IG.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 20000, [ref]$r); $r.ToInt64() }
$SCI = @{ GOTOLINE = 2024; GETELEMENTCOLOUR = 2754; GETINDENTATIONGUIDES = 2133; POINTX = 2164; POINTY = 2165; POSITIONFROMLINE = 2167
	TEXTHEIGHT = 2279; MARGINWIDTHN = 2243; SETFIRSTVISIBLELINE = 2613; SETTECHNOLOGY = 2630
	GETINDENTGUIDESOLID = 5111; UPDATEACTIVEINDENTGUIDE = 5112; GETACTIVEINDENTGUIDE = 5113 }
$ELEMENT = @{ CARETLINENUMBER = 5120; ACTIVEINDENTGUIDE = 5121 }
$IDM_VIEW_INDENT_GUIDE = 44020; $IDM_SETTING_PREFERENCE = 48011; $IDC_COMBO_INDENTGUIDES = 7216

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-indent-guides-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $root | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
# Python, 4 spaces a level: the blocks expected for a caret on each line, (column, first line, last line); column 0: none
$pyFile = Join-Path $root 'blocks.py'
[IO.File]::WriteAllText($pyFile, ((@('class Item:', '    def value(self):', '        x = 1', '', '        return x', '', '    def other(self):',
	'        if x:', '            y = 2', '        return y', 'z = 3') -join "`r`n") + "`r`n"), $utf8)
$pyExpected = @( # line, column, first, last, what
	@(2, 4, 2, 4, 'a body line: the guide of the block it is in'),
	@(1, 4, 2, 4, 'a line a block hangs from (the next one indented further): that block'),
	@(3, 4, 2, 4, 'a blank line in a block: that block'),
	@(5, 4, 2, 4, 'a blank line after a block: the deeper of the blocks around it'),
	@(8, 8, 8, 8, 'a nested block: its own guide'),
	@(9, 4, 7, 9, 'a line after a nested block: the outer block, nested lines included'),
	@(0, 0, 0, -1, 'a top-level line a block hangs from: none (no guide is drawn at column 0)'),
	@(10, 0, 0, -1, 'a top-level line: none')
)
# C++ with tabs (4 columns) and braces on their own lines
$cppFile = Join-Path $root 'braces.cpp'
[IO.File]::WriteAllText($cppFile, ((@('int f()', '{', "`tif (a)", "`t{", "`t`tg();", "`t}", '}') -join "`r`n") + "`r`n"), $utf8)
# a block of 200,000 lines
$bigFile = Join-Path $root 'big.py'
$sb = [Text.StringBuilder]::new(); [void]$sb.Append("class Big:`r`n    def f(self):`r`n")
foreach ($i in 1..200000) { [void]$sb.Append("        x = $i`r`n") }
[IO.File]::WriteAllText($bigFile, $sb.ToString(), $utf8)

$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
$model = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32"[^>]*?fontName=")[^"]*("[^>]*?fontSize=")[^"]*"', "`${1}Consolas`${2}11`"")
# a theme of pure colours: the guides green, the caret block's guide blue, the caret line's number red
$coloured = [regex]::Replace($model, '(<WidgetStyle name="Indent guideline style" styleID="37" fgColor=")[0-9A-Fa-f]{6}"', "`${1}00C000`"")
$coloured = $coloured.Replace('</GlobalStyles>', "    <WidgetStyle name=`"Current line number`" styleID=`"0`" fgColor=`"FF0000`" />`r`n        <WidgetStyle name=`"Active indent guideline`" styleID=`"0`" fgColor=`"0000FF`" />`r`n    </GlobalStyles>")

function Start-Npp([string] $name, [string] $theme, [string[]] $open, [string] $config = '') {
	$settings = Join-Path $root $name; New-Item -ItemType Directory -Force $settings | Out-Null
	if (-not (Test-Path (Join-Path $settings 'stylers.xml'))) { [IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $theme, $utf8) }
	if ($config) { [IO.File]::WriteAllText((Join-Path $settings 'config.xml'), $config, $utf8) }
	$p = Start-Process $Exe -ArgumentList (@('-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST') + @($open | ForEach-Object { "`"$_`"" })) -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	$script:main = $p.MainWindowHandle; $script:settings = $settings; $script:nppId = $p.Id
	$h = [IntPtr]::Zero; $script:sc = [IntPtr]::Zero
	while (($h = [IG.U]::FindWindowEx($script:main, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($script:sc -eq [IntPtr]::Zero -and [IG.U]::IsWindowVisible($h)) { $script:sc = $h } }
	if ((Send $script:sc $SCI.GETINDENTATIONGUIDES) -eq 0) { [void](Send $script:main 0x0111 $IDM_VIEW_INDENT_GUIDE) }
	$p
}
function Stop-Npp($p) {
	[void][IG.U]::PostMessage($script:main, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force }
}
# the caret put on a line (Notepad++ updates the block at SCN_UPDATEUI), then the block read: "column first last"
function Block-At([int] $line) {
	[void](Send $script:sc $SCI.GOTOLINE $line); Start-Sleep -Milliseconds 300
	'{0} {1} {2}' -f (Send $script:sc $SCI.GETACTIVEINDENTGUIDE 0), (Send $script:sc $SCI.GETACTIVEINDENTGUIDE 1), (Send $script:sc $SCI.GETACTIVEINDENTGUIDE 2)
}
function Hex([int64] $v) { '{0:X8}' -f ($v -band 0xFFFFFFFFL) }

# pixels: the window copied, a line's rows that hold a pixel of a colour in a band of columns (client coordinates).
# -Screen: what the screen shows, the window brought to the front (PrintWindow makes the window paint itself whole again,
# which would hide what wasn't redrawn after a caret move)
function Get-Capture([switch] $Screen) {
	$rm = [IG.U+RECT]::new(); [void][IG.U]::GetWindowRect($script:main, [ref]$rm); $pt = [IG.U+POINT]::new(); [void][IG.U]::ClientToScreen($script:sc, [ref]$pt)
	$bmp = [Drawing.Bitmap]::new($rm.Right - $rm.Left, $rm.Bottom - $rm.Top); $g = [Drawing.Graphics]::FromImage($bmp)
	if ($Screen) { $g.CopyFromScreen($rm.Left, $rm.Top, 0, 0, $bmp.Size) }
	else { $hdc = $g.GetHdc(); [void][IG.U]::PrintWindow($script:main, $hdc, 2); $g.ReleaseHdc($hdc) }
	$g.Dispose()
	@{ Bitmap = $bmp; X = $pt.X - $rm.Left; Y = $pt.Y - $rm.Top }
}
function Bring-ToFront { [void][IG.U]::ShowWindow($script:main, 9); [void][IG.U]::SetForegroundWindow($script:main); Start-Sleep -Milliseconds 500 }
$isRed = { param($c) ($c.R -gt 150) -and ($c.G -lt 90) -and ($c.B -lt 90) }
$isBlue = { param($c) ($c.B -gt 150) -and ($c.R -lt 90) -and ($c.G -lt 90) }
$isGreen = { param($c) ($c.G -gt 110) -and ($c.R -lt 80) -and ($c.B -lt 80) }
function Rows-Of($capture, [int] $line, [int] $x1, [int] $x2, [scriptblock] $test) { # the share of the line's rows
	$y1 = Send $script:sc $SCI.POINTY 0 (Send $script:sc $SCI.POSITIONFROMLINE $line); $height = Send $script:sc $SCI.TEXTHEIGHT $line
	$rows = 0
	for ($y = $y1; $y -lt $y1 + $height; $y++) {
		for ($x = $x1; $x -lt $x2; $x++) { if (& $test $capture.Bitmap.GetPixel($x + $capture.X, $y + $capture.Y)) { $rows++; break } }
	}
	[double]$rows / $height
}
# the guide at a column of a line (a band around where Scintilla draws it: the column's x + 1)
function Guide-Rows($capture, [int] $line, [int] $column, [scriptblock] $test) {
	$x = Send $script:sc $SCI.POINTX 0 ((Send $script:sc $SCI.POSITIONFROMLINE $line) + $column)
	Rows-Of $capture $line ($x - 1) ($x + 3) $test
}
function Number-Rows($capture, [int] $line, [scriptblock] $test) { Rows-Of $capture $line 0 (Send $script:sc $SCI.MARGINWIDTHN 0) $test }
function Fmt([double[]] $values) { ($values | ForEach-Object { '{0:N2}' -f $_ }) -join ' / ' }

try {
	# --- the default theme (stylers.model.xml, without the two styles): their default colours; the blocks
	$p = Start-Npp 'defaults' $model @($cppFile, $pyFile)
	$numberColour = Send $script:sc $SCI.GETELEMENTCOLOUR $ELEMENT.CARETLINENUMBER; $guideColour = Send $script:sc $SCI.GETELEMENTCOLOUR $ELEMENT.ACTIVEINDENTGUIDE
	Check 'a theme without them: "Current line number" the text''s colour (000000), "Active indent guideline" 45% from the guides'' colour to the text''s (C0C0C0 to 000000: 6A6A6A)' (((Hex $numberColour) -eq 'FF000000') -and ((Hex $guideColour) -eq 'FF6A6A6A')) "$(Hex $numberColour), $(Hex $guideColour)"
	Check 'by default the guides solid' ((Send $script:sc $SCI.GETINDENTGUIDESOLID) -eq 1)
	foreach ($want in $pyExpected) {
		$got = Block-At $want[0]; $expected = '{0} {1} {2}' -f $want[1], $want[2], $want[3]
		Check "  Python, caret on line $($want[0]): $($want[4])" ($got -eq $expected) "column, first, last: $got (expected $expected)"
	}
	Stop-Npp $p
	# a theme whose text is as grey as its line numbers: the number black (it would not stand out)
	$greyText = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32" fgColor=")[0-9A-Fa-f]{6}"', "`${1}808080`"")
	$p = Start-Npp 'grey-text' $greyText @($cppFile, $pyFile)
	$greyNumber = Send $script:sc $SCI.GETELEMENTCOLOUR $ELEMENT.CARETLINENUMBER
	Check '  a theme whose text is the line numbers'' colour (808080): the number black' ((Hex $greyNumber) -eq 'FF000000') (Hex $greyNumber)
	[void](Send $script:main 0x0111 44096) # the previous tab: braces.cpp
	Start-Sleep -Milliseconds 300
	$inner = Block-At 4; $ifLine = Block-At 2
	Check '  C++ with tabs: in braces at one tab, the guide at 4 columns on the lines between them; the "if" line in a block hanging from column 0: none' (($inner -eq '4 4 4') -and ($ifLine.StartsWith('0 '))) "line 4: $inner; line 2: $ifLine"
	Stop-Npp $p

	# --- a block of 200,000 lines: the cost of an update, the lines read
	$p = Start-Npp 'big' $model @($bigFile)
	$near = Block-At 5000
	$sw = [Diagnostics.Stopwatch]::StartNew()
	foreach ($i in 1..200) { [void](Send $script:sc $SCI.UPDATEACTIVEINDENTGUIDE 1) }
	$perUpdate = $sw.Elapsed.TotalMilliseconds / 200
	$far = Block-At 150000
	Check 'a block of 200,000 lines, caret 5,000 lines into it: highlighted (column 4, from line 2); an update unchanged under 5 ms' (($near -split ' ')[0] -eq '4' -and ($near -split ' ')[1] -eq '2' -and $perUpdate -lt 5) ("{0}; {1:N2} ms an update" -f $near, $perUpdate)
	Info "caret 150,000 lines into it (its first line more than 10,000 lines above the view): $far (column 0: not looked for so far)"
	Stop-Npp $p

	# --- pure colours: the pixels, DirectWrite then GDI; smart highlighting off (it repaints at each caret move, which would
	# hide a margin not drawn again)
	$p = Start-Npp 'colours' $coloured @($pyFile) '<?xml version="1.0" encoding="UTF-8" ?><NotepadPlus><GUIConfigs><GUIConfig name="SmartHighLight" matchCase="no" wholeWordOnly="yes" useFindSettings="no" onAnotherView="no">no</GUIConfig><GUIConfig name="ScintillaPrimaryView" folderMarkStyle="none" /></GUIConfigs></NotepadPlus>'
	foreach ($tech in @(@(1, 'DirectWrite'), @(0, 'GDI'))) {
		[void](Send $script:sc $SCI.SETTECHNOLOGY $tech[0]); Start-Sleep -Milliseconds 400
		[void](Send $script:sc $SCI.SETFIRSTVISIBLELINE 0); $null = Block-At 2; Start-Sleep -Milliseconds 300
		$c = Get-Capture
		$active = @((Guide-Rows $c 2 4 $isBlue), (Guide-Rows $c 4 4 $isBlue))
		$others = @((Guide-Rows $c 8 4 $isBlue), (Guide-Rows $c 8 8 $isBlue), (Guide-Rows $c 9 4 $isBlue))
		$normal = @((Guide-Rows $c 8 4 $isGreen), (Guide-Rows $c 8 8 $isGreen))
		$numbers = @((Number-Rows $c 2 $isRed), (Number-Rows $c 4 $isRed), (Number-Rows $c 8 $isRed))
		$c.Bitmap.Dispose()
		Check "$($tech[1]), caret on line 2: its block's guide in its colour, solid (lines 2 and 4); no other guide in it; the others solid in theirs" ((@($active | Where-Object { $_ -lt 0.85 }).Count -eq 0) -and (@($others | Where-Object { $_ -gt 0 }).Count -eq 0) -and (@($normal | Where-Object { $_ -lt 0.85 }).Count -eq 0)) "rows: active $(Fmt $active); others in its colour $(Fmt $others); others in theirs $(Fmt $normal)"
		Check "  the caret line's number in its colour, the other numbers not" (($numbers[0] -gt 0.2) -and ($numbers[1] -eq 0) -and ($numbers[2] -eq 0)) "rows in red, lines 2 / 4 / 8: $(Fmt $numbers)"
		Bring-ToFront; $null = Block-At 8; Start-Sleep -Milliseconds 300
		$c = Get-Capture -Screen
		$moved = @((Guide-Rows $c 8 8 $isBlue), (Guide-Rows $c 8 4 $isBlue), (Guide-Rows $c 2 4 $isBlue), (Guide-Rows $c 2 4 $isGreen))
		$numbersMoved = @((Number-Rows $c 8 $isRed), (Number-Rows $c 2 $isRed))
		$c.Bitmap.Dispose()
		Check "  caret moved to line 8: the nested block's guide highlighted, line 2's drawn as the others; the number's colour moved with the caret (the margin drawn again)" (($moved[0] -ge 0.85) -and ($moved[1] -eq 0) -and ($moved[2] -eq 0) -and ($moved[3] -ge 0.85) -and ($numbersMoved[0] -gt 0.2) -and ($numbersMoved[1] -eq 0)) "line 8 col 8 / line 8 col 4 / line 2 col 4 in blue, line 2 col 4 in green: $(Fmt $moved); red numbers lines 8 / 2: $(Fmt $numbersMoved)"
		# Left at the start of line 4: to the end of line 3, in the same block (nothing else redrawn)
		$null = Block-At 4; [void](Send $script:sc 2304); Start-Sleep -Milliseconds 400 # SCI_CHARLEFT
		$c = Get-Capture -Screen
		$numbersLeft = @((Number-Rows $c 3 $isRed), (Number-Rows $c 4 $isRed))
		$c.Bitmap.Dispose()
		Check "  Left from the start of line 4 to line 3 (the same block): the number's colour moved too" (($numbersLeft[0] -gt 0.2) -and ($numbersLeft[1] -eq 0)) "red numbers lines 3 / 4: $(Fmt $numbersLeft)"
	}
	[void](Send $script:sc $SCI.SETTECHNOLOGY 1)

	# --- Preferences: the combo box, Dotted chosen, applied at once
	[void][IG.U]::PostMessage($script:main, 0x0111, [IntPtr]$IDM_SETTING_PREFERENCE, [IntPtr]::Zero); Start-Sleep -Milliseconds 1500
	$prefs = [IG.U]::FindDialog($script:nppId, 'Preferences')
	$combo = if ($prefs -ne [IntPtr]::Zero) { [IG.U]::FindById($prefs, $IDC_COMBO_INDENTGUIDES) } else { [IntPtr]::Zero }
	$items = if ($combo -ne [IntPtr]::Zero) { Send $combo 0x0146 } else { -1 }; $selected = if ($combo -ne [IntPtr]::Zero) { Send $combo 0x0147 } else { -1 }
	Check 'Preferences > Margins/Border/Edge: the Indent Guides combo box, 3 styles, the default chosen' (($items -eq 3) -and ($selected -eq 2)) "items $items, selected $selected"
	if ($combo -ne [IntPtr]::Zero) {
		[void](Send $combo 0x014E 0) # CB_SETCURSEL: Dotted
		[void](Send ([IG.U]::GetParent($combo)) 0x0111 ((1 -shl 16) -bor $IDC_COMBO_INDENTGUIDES) ([Int64]$combo)) # CBN_SELCHANGE
		Start-Sleep -Milliseconds 300
		$solid = Send $script:sc $SCI.GETINDENTGUIDESOLID; $column = Send $script:sc $SCI.GETACTIVEINDENTGUIDE 0
		Check '  Dotted chosen: applied at once (the guides dotted, no block highlighted)' (($solid -eq 0) -and ($column -eq 0)) "solid $solid, active column $column"
		[void][IG.U]::PostMessage($prefs, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 500
	}
	Stop-Npp $p
	$config = [IO.File]::ReadAllText((Join-Path $script:settings 'config.xml'))
	Check '  saved in config.xml (indentGuideStyle="dotted")' ($config.Contains('indentGuideStyle="dotted"'))

	# --- read back: dotted pixels; the caret line's number keeps its colour; Solid alone
	$p = Start-Npp 'colours' $coloured @($pyFile)
	$null = Block-At 2; Start-Sleep -Milliseconds 300
	$c = Get-Capture
	$dotted = @((Guide-Rows $c 8 4 $isGreen), (Guide-Rows $c 2 4 $isGreen))
	$blue = Guide-Rows $c 2 4 $isBlue; $number = Number-Rows $c 2 $isRed
	$c.Bitmap.Dispose()
	Check 'read back: Dotted, the guides one row in two, none highlighted; the caret line''s number still in its colour' (((Send $script:sc $SCI.GETINDENTGUIDESOLID) -eq 0) -and (@($dotted | Where-Object { ($_ -lt 0.3) -or ($_ -gt 0.7) }).Count -eq 0) -and ($blue -eq 0) -and ($number -gt 0.2)) "rows in green (lines 8, 2): $(Fmt $dotted); in blue $(Fmt $blue); red number $(Fmt $number)"
	[void][IG.U]::PostMessage($script:main, 0x0111, [IntPtr]$IDM_SETTING_PREFERENCE, [IntPtr]::Zero); Start-Sleep -Milliseconds 1500
	$prefs = [IG.U]::FindDialog($script:nppId, 'Preferences')
	$combo = if ($prefs -ne [IntPtr]::Zero) { [IG.U]::FindById($prefs, $IDC_COMBO_INDENTGUIDES) } else { [IntPtr]::Zero }
	if ($combo -ne [IntPtr]::Zero) {
		$selected = Send $combo 0x0147
		[void](Send $combo 0x014E 1) # Solid
		[void](Send ([IG.U]::GetParent($combo)) 0x0111 ((1 -shl 16) -bor $IDC_COMBO_INDENTGUIDES) ([Int64]$combo))
		$null = Block-At 4
		$solid = Send $script:sc $SCI.GETINDENTGUIDESOLID; $column = Send $script:sc $SCI.GETACTIVEINDENTGUIDE 0
		Check '  the combo box showing Dotted; Solid chosen: solid guides, still none highlighted after a caret move' (($selected -eq 0) -and ($solid -eq 1) -and ($column -eq 0)) "selected $selected; solid $solid, active column $column"
		[void][IG.U]::PostMessage($prefs, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 500
	}
	else { Check '  the Preferences dialog' $false 'not found' }
	Stop-Npp $p
}
finally {
	Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -like '*REVIEW-TEST*' } | Stop-Process -Force
	$script:results
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
