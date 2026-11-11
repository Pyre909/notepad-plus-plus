# App-level test (review harness), Pyre909 builds only: View > Show Symbol > "Show Characters on a Grid" (config.xml
# characterGrid; pyre's SCI_SETCHARACTERGRID). On a grid of cells (a cell: the width of a space of the Default Style), a tab
# is one tab size wide wherever it is and every representation takes whole cells: control characters, DEL, the
# non-printing characters' labels, invalid bytes, CR of a line end. Checked from where each character starts
# (SCI_POINTXFROMPOSITION, within a pixel: positions are whole pixels): code, an INI file, a TSV table, a Makefile line,
# control and invisible characters, invalid bytes, in Consolas with GDI and DirectWrite, zoomed in, wrapped, in the second
# view; CJK in BIZ UDGothic (a 2:1 font: two cells each; skipped if the font isn't installed); in Segoe UI (proportional:
# the tabs and representations in whole cells, letters as wide as the font makes them). Off: the tab stops; off again:
# the same positions as before it was on; saved in config.xml and read back. Hidden control characters (Show Control
# Characters off) keep no width, also on a line over 2,000 bytes (Scintilla's table of their widths, reset when the
# representations change); Down after a toggle goes below where the caret is now. Unicode's widths (CJK, emoji, keycaps,
# combining marks, decomposed Hangul); a hidden RLO reorders nothing (pixels compared, DirectWrite and GDI); an ANSI and
# a GBK document; virtual space in Segoe UI in cells; whole-pixel cells (each 0 of a line drawn alike). Not driven: printing (printed without it), the edge's background
# mode, the centring and narrowing of glyphs and the block caret (screenshots only).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace CG -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr m, uint id, uint flags);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Info([string] $text) { $script:results.Add("INFO  $text") }
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][CG.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }
$IDM_VIEW_CHARACTER_GRID = 44190; $IDM_VIEW_ALL_CHARACTERS = 44019; $IDM_VIEW_GOTO_ANOTHER_VIEW = 10001; $IDM_VIEW_NPC_CCUNIEOL = 44131; $IDM_VIEW_NPC = 44130
$SCI = @{ GETLINECOUNT = 2154; POSITIONFROMLINE = 2167; GETLINEENDPOSITION = 2136; POINTX = 2164; POSITIONRELATIVE = 2418; GETCHARAT = 2007
	SETTECHNOLOGY = 2630; SETZOOM = 2373; SETWRAPMODE = 2268; LINEFROMPOSITION = 2166; POINTY = 2165; GETCHARACTERGRID = 5104; GETTABWIDTH = 2121 }

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-character-grid-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $root | Out-Null
$T = "`t"; $utf8 = [Text.UTF8Encoding]::new($false)
# line 1: the space line (the cell); then the lines whose every character must start on the grid in a monospaced font
$gridLines = @(
	((' ' * 160) + 'X'),
	"#include <cstdio>${T}// a tab after an include",
	"${T}int x;${T}${T}// two tabs",
	"${T}${T}std::printf(`"%d\t%d\n`", p.x, p.y);${T}// escaped tab",
	"host${T}= example.com",
	"timeout_seconds${T}= 30",
	"22${T}Bartholomew${T}Rio de Janeiro${T}7",
	"${T}cc -o app main.c${T}# a Makefile recipe",
	("C0: NUL[" + [char]0 + "] BEL[" + [char]7 + "] ESC[" + [char]27 + "] DEL[" + [char]127 + "]"),
	("Invisible: NBSP[" + [char]0xA0 + "] ZWSP[" + [char]0x200B + "] BOM[" + [char]0xFEFF + "] SHY[" + [char]0xAD + "]"),
	("Unicode ends: NEL[" + [char]0x85 + "] LS[" + [char]0x2028 + "]${T}end"))
$cjkLines = @("English and 中文混排${T}end", "日本語のテキスト：ひらがな、カタカナ。", "한국어 텍스트와 English", "Tab${T}和${T}中文${T}end")
$bytes = [Collections.Generic.List[byte]]::new(); $bytes.AddRange([byte[]](0xEF, 0xBB, 0xBF))
$bytes.AddRange($utf8.GetBytes(($gridLines -join "`r`n") + "`r`n" + ($cjkLines -join "`r`n") + "`r`nBad bytes: ["))
$bytes.Add(0xE9); $bytes.AddRange($utf8.GetBytes("] [")); $bytes.Add(0xFF); $bytes.AddRange($utf8.GetBytes("]${T}end`r`n"))
$file = Join-Path $root 'grid.txt'; [IO.File]::WriteAllBytes($file, $bytes.ToArray())
$cjkFirst = $gridLines.Count; $badLine = $gridLines.Count + $cjkLines.Count # 0-based line numbers
$fonts = [Drawing.Text.InstalledFontCollection]::new().Families.Name

function Start-Npp([string] $font, [string] $open = $file) {
	$settings = Join-Path $root ($font -replace '\s', ''); New-Item -ItemType Directory -Force $settings | Out-Null
	if (-not (Test-Path (Join-Path $settings 'stylers.xml'))) {
		$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
		$model = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32"[^>]*?fontName=")[^"]*("[^>]*?fontSize=")[^"]*"', "`${1}$font`${2}10`"")
		[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model, $utf8)
	}
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', "`"$open`"" -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	$script:main = $p.MainWindowHandle; $script:settings = $settings
	$script:sc = Get-View
	$p
}
function Get-View { $h = [IntPtr]::Zero; while (($h = [CG.U]::FindWindowEx($script:main, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ([CG.U]::IsWindowVisible($h) -and (Send $h 2006) -gt 100) { return $h } }; [IntPtr]::Zero }
function Stop-Npp($p) { [void][CG.U]::PostMessage($script:main, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force } }
function Grid-On { (Send $script:sc $SCI.GETCHARACTERGRID) -ne 0 }
# the cell: the width of a space, over 160 of them (positions are whole pixels; DirectWrite's are fractional)
function Get-Cell { $p0 = Send $script:sc $SCI.POSITIONFROMLINE 0; ((Send $script:sc $SCI.POINTX 0 ($p0 + 160)) - (Send $script:sc $SCI.POINTX 0 $p0)) / 160.0 }
# each character of a line: start x relative to its (sub)line's start, its width, whether it's a tab
function Get-Chars([int] $line) {
	$start = Send $script:sc $SCI.POSITIONFROMLINE $line; $end = Send $script:sc $SCI.GETLINEENDPOSITION $line
	$out = [Collections.Generic.List[object]]::new(); $pos = $start; $y0 = Send $script:sc $SCI.POINTY 0 $start; $x0 = Send $script:sc $SCI.POINTX 0 $start
	while ($pos -le $end) {
		$y = Send $script:sc $SCI.POINTY 0 $pos; if ($y -ne $y0) { $y0 = $y; $x0 = Send $script:sc $SCI.POINTX 0 $pos } # a wrapped subline: its own start
		# the line end: where it starts only (between its CR and LF is no position to measure its width from)
		$next = if ($pos -lt $end) { Send $script:sc $SCI.POSITIONRELATIVE $pos 1 } else { $pos }
		$x = Send $script:sc $SCI.POINTX 0 $pos; $xn = Send $script:sc $SCI.POINTX 0 $next
		$out.Add([pscustomobject]@{ Pos = $pos; X = $x - $x0; W = $xn - $x; Ch = (Send $script:sc $SCI.GETCHARAT $pos); SameLine = ($pos -lt $end -and (Send $script:sc $SCI.POINTY 0 $next) -eq $y) })
		if ($pos -eq $end) { break }
		$pos = $next
	}
	$out
}
function On-Grid([double] $v, [double] $cell) { [Math]::Abs($v - [Math]::Round($v / $cell) * $cell) -le 1.01 }
# the view drawn by PrintWindow, in its pixels (per-monitor aware meanwhile), and where a position's pixels are in it
function Get-Capture {
	$old = [CG.U]::SetThreadDpiAwarenessContext([IntPtr](-4))
	try {
		$r = [CG.U+RECT]::new(); [void][CG.U]::GetWindowRect($script:main, [ref]$r)
		$o = [CG.U+POINT]::new(); [void][CG.U]::ClientToScreen($script:sc, [ref]$o)
		$bmp = [Drawing.Bitmap]::new($r.Right - $r.Left, $r.Bottom - $r.Top)
		$g = [Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc(); [void][CG.U]::PrintWindow($script:main, $hdc, 2); $g.ReleaseHdc($hdc); $g.Dispose()
		[pscustomobject]@{ Bitmap = $bmp; X = $o.X - $r.Left; Y = $o.Y - $r.Top }
	}
	finally { [void][CG.U]::SetThreadDpiAwarenessContext($old) }
}
function Cell-Pixels($capture, [long] $pos, [int] $width, [int] $height) {
	$x0 = $capture.X + (Send $script:sc $SCI.POINTX 0 $pos); $y0 = $capture.Y + (Send $script:sc $SCI.POINTY 0 $pos)
	$sb = [Text.StringBuilder]::new()
	for ($y = 0; $y -lt $height; $y++) { for ($x = 0; $x -lt $width; $x++) { [void]$sb.Append($capture.Bitmap.GetPixel($x0 + $x, $y0 + $y).ToArgb()).Append(',') } }
	$sb.ToString()
}
# the pixels of cells from two positions compared
function Different-Pixels([long] $a, [long] $b, [int] $cells) {
	$capture = Get-Capture
	$height = Send $script:sc 2279 (Send $script:sc $SCI.LINEFROMPOSITION $a); $width = [int]($cells * (Get-Cell))
	$pa = (Cell-Pixels $capture $a $width $height) -split ','; $pb = (Cell-Pixels $capture $b $width $height) -split ','
	$capture.Bitmap.Dispose()
	@(for ($i = 0; $i -lt $pa.Count; $i++) { if ($pa[$i] -ne $pb[$i]) { 1 } }).Count
}
# the characters of the lines that start off the grid (x within a pixel of whole cells), and the tabs not tabSize cells
function Test-Lines([int[]] $lines, [double] $cell, [switch] $OnlyTabsAndReps) {
	$tab = Send $script:sc $SCI.GETTABWIDTH; $bad = @()
	foreach ($l in $lines) {
		foreach ($c in (Get-Chars $l)) {
			if ($c.Ch -eq 9 -and $c.SameLine -and [Math]::Abs($c.W - $tab * $cell) -gt 1.01) { $bad += "line $($l + 1) tab $($c.W) px" }
			$isRep = ($c.Ch -ge 0 -and $c.Ch -lt 32 -and $c.Ch -ne 9) -or $c.Ch -eq 127 -or $c.Ch -lt 0 # control, DEL, a byte >= 0x80 (signed char)
			if ($OnlyTabsAndReps) {
				if ($isRep -and $c.SameLine -and -not (On-Grid $c.W $cell)) { $bad += "line $($l + 1) label at $($c.Pos): $($c.W) px" }
			}
			elseif (-not (On-Grid $c.X $cell)) { $bad += "line $($l + 1) at $($c.Pos): x $($c.X)" }
		}
	}
	$bad
}
$monoLines = 1..($gridLines.Count - 1) + $badLine

try {
	# --- Consolas: off, then on (DirectWrite, GDI), zoomed, wrapped, the other view, off again
	$p = Start-Npp 'Consolas'
	[void](Send $script:main 0x0111 $IDM_VIEW_ALL_CHARACTERS)
	$cell = Get-Cell
	$offTabs = @((Get-Chars 6) | Where-Object { $_.Ch -eq 9 } | ForEach-Object { [Math]::Round($_.W / $cell, 1) })
	$offPositions = ($monoLines | ForEach-Object { (Get-Chars $_).X }) -join ','
	Check 'off (the default): unchecked, tabs to the tab stops' ((-not (Grid-On)) -and ($offTabs -join ',') -eq '2,1,2') "TSV line's tabs: $($offTabs -join ', ') cells"
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID)
	$menu = ([CG.U]::GetMenuState([CG.U]::GetMenu($script:main), $IDM_VIEW_CHARACTER_GRID, 0) -band 8) -ne 0
	foreach ($tech in @(@(1, 'DirectWrite'), @(0, 'GDI'))) {
		[void](Send $script:sc $SCI.SETTECHNOLOGY $tech[0]); Start-Sleep -Milliseconds 300
		$cell = Get-Cell; $bad = Test-Lines $monoLines $cell
		Check "on, Consolas, $($tech[1]): every character of code, config, control and invisible characters and invalid bytes on the grid (tabs $(Send $script:sc $SCI.GETTABWIDTH) cells)" ((Grid-On) -and $menu -and $bad.Count -eq 0) $(if ($bad) { ($bad | Select-Object -First 4) -join '; ' } else { "cell {0:N2} px" -f $cell })
	}
	[void](Send $script:sc $SCI.SETTECHNOLOGY 1)
	[void](Send $script:sc $SCI.SETZOOM 4); Start-Sleep -Milliseconds 300
	$cell = Get-Cell; $bad = Test-Lines $monoLines $cell
	Check '  zoomed in (+4): still on the grid' ($bad.Count -eq 0) $(if ($bad) { ($bad | Select-Object -First 4) -join '; ' } else { "cell {0:N2} px" -f $cell })
	[void](Send $script:sc $SCI.SETZOOM 0)
	$cell = Get-Cell # before the space line wraps
	[void](Send $script:sc $SCI.SETWRAPMODE 1); [void](Send $script:sc 0x0005 0 ((400 -shl 16) -bor 260)); Start-Sleep -Milliseconds 300 # WM_SIZE: a narrow view
	$bad = Test-Lines $monoLines $cell
	Check '  wrapped in a narrow view: each subline on the grid' ($bad.Count -eq 0) $(if ($bad) { ($bad | Select-Object -First 4) -join '; ' } else { 'ok' })
	[void](Send $script:sc $SCI.SETWRAPMODE 0); [void](Send $script:main 0x0005 0 0)
	[void](Send $script:main 0x0111 $IDM_VIEW_GOTO_ANOTHER_VIEW); Start-Sleep -Milliseconds 500
	$script:sc = Get-View; $cell = Get-Cell; $bad = Test-Lines $monoLines $cell
	Check '  the second view too' ((Grid-On) -and $bad.Count -eq 0) $(if ($bad) { ($bad | Select-Object -First 4) -join '; ' } else { 'ok' })
	[void](Send $script:main 0x0111 $IDM_VIEW_GOTO_ANOTHER_VIEW); Start-Sleep -Milliseconds 500; $script:sc = Get-View
	$cell = Get-Cell
	$cjkOff = Test-Lines ($cjkFirst..($cjkFirst + $cjkLines.Count - 1)) $cell
	# (positions are whole pixels, truncated: widths in cells rounded, the positions checked on the grid within a pixel above)
	$cjkWide = @((Get-Chars ($cjkFirst + 1)) | Where-Object { $_.Ch -lt 0 -and $_.W -gt 0 } | ForEach-Object { [Math]::Round($_.W / $cell) } | Sort-Object -Unique)
	Check 'Consolas, which has no CJK (another font draws it): every CJK character on the grid, two cells each (fitted in them)' ($cjkOff.Count -eq 0 -and ($cjkWide -join ',') -eq '2') $(if ($cjkOff) { ($cjkOff | Select-Object -First 4) -join '; ' } else { "CJK widths: $($cjkWide -join ', ') cells" })
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID)
	$cell = Get-Cell; $again = ($monoLines | ForEach-Object { (Get-Chars $_).X }) -join ','
	Check 'off again: every position as before it was on' ((-not (Grid-On)) -and $again -eq $offPositions)
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) # left on
	Stop-Npp $p
	Check 'saved: config.xml characterGrid="yes"' ((Get-Content -LiteralPath (Join-Path $script:settings 'config.xml') -Raw) -match 'characterGrid="yes"')
	$p = Start-Npp 'Consolas'
	Check '  read back at the next start: on, checked' ((Grid-On) -and (([CG.U]::GetMenuState([CG.U]::GetMenu($script:main), $IDM_VIEW_CHARACTER_GRID, 0) -band 8) -ne 0))
	Stop-Npp $p

	# --- BIZ UDGothic (2:1): CJK on the grid, two cells each
	if ($fonts -contains 'BIZ UDGothic') {
		$p = Start-Npp 'BIZ UDGothic'
		[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID); [void](Send $script:main 0x0111 $IDM_VIEW_ALL_CHARACTERS)
		$cell = Get-Cell
		$bad = Test-Lines (@($monoLines) + ($cjkFirst..($cjkFirst + $cjkLines.Count - 1))) $cell
		$wide = @((Get-Chars ($cjkFirst + 1)) | Where-Object { $_.Ch -lt 0 -and $_.W -gt 0 } | ForEach-Object { [Math]::Round($_.W / $cell, 2) } | Sort-Object -Unique)
		Check 'BIZ UDGothic (2:1): every character on the grid, CJK included, two cells each' ($bad.Count -eq 0 -and ($wide -join ',') -eq '2') $(if ($bad) { ($bad | Select-Object -First 4) -join '; ' } else { "CJK widths: $($wide -join ', ') cells" })
		Stop-Npp $p
	}
	else { Info 'BIZ UDGothic not installed: the 2:1 check skipped' }

	# --- Segoe UI (proportional): the tabs and representations in whole cells
	$p = Start-Npp 'Segoe UI'
	[void](Send $script:main 0x0111 $IDM_VIEW_ALL_CHARACTERS)
	if (-not (Grid-On)) { [void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) }
	$cell = Get-Cell; $bad = Test-Lines $monoLines $cell
	Check 'Segoe UI (proportional): every character on the grid too, letters fitted in their cells (a cell as wide as its "0")' ($bad.Count -eq 0) $(if ($bad) { ($bad | Select-Object -First 4) -join '; ' } else { "cell {0:N2} px" -f $cell })
	Stop-Npp $p

	# --- hidden control characters, a line over 2,000 bytes (Scintilla's table of control characters' widths), the caret
	$ccFile = Join-Path $root 'control.txt'
	# lines 5 to 12: Unicode's widths, an x after each: half-width katakana, a combining accent, U+2764 U+FE0F, an emoji,
	# an emoji with its skin tone (its parts: 2 + 2 cells), a keycap (# U+FE0F U+20E3), a decomposed Hangul syllable (U+1112
	# U+1161 U+11AB: its vowel and final consonant with the first), a combining accent after a tab (one cell: seen);
	# lines 13 and 14: "ab cd ef", then the same after a hidden RLO (U+202E): drawn alike, in the characters' order;
	# line 15: 24 zeros, each drawn alike (whole-pixel cells); lines 16 and 17: 24 box drawing lines (U+2500) and 24 quotes
	# (U+201C), drawn in a batch since 2026-11-10, each alike too
	$widthLines = @(([string][char]0xFF76 + [char]0xFF80 + 'x'), ('e' + [char]0x301 + 'x'), ([string][char]0x2764 + [char]0xFE0F + 'x'),
		([char]::ConvertFromUtf32(0x1F600) + 'x'), ([char]::ConvertFromUtf32(0x1F44D) + [char]::ConvertFromUtf32(0x1F3FD) + 'x'),
		('#' + [char]0xFE0F + [char]0x20E3 + 'x'), ([string][char]0x1112 + [char]0x1161 + [char]0x11AB + 'x'), ($T + [char]0x301 + 'x'),
		'ab cd ef', ([string][char]0x202E + 'ab cd ef'), ('0' * 24), ([string][char]0x2500 * 24), ([string][char]0x201C * 24))
	[IO.File]::WriteAllText($ccFile, ($gridLines[0] + "`r`na" + [char]0 + "b`r`n" + ('x' * 2500) + [char]0 + "b`r`nab${T}c`r`n0123456789`r`n" + ($widthLines -join "`r`n") + "`r`n"), $utf8)
	$p = Start-Npp 'Consolas' $ccFile
	if (-not (Grid-On)) { [void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) }
	$short = (Send $script:sc $SCI.POSITIONFROMLINE 1) + 1; $long = (Send $script:sc $SCI.POSITIONFROMLINE 2) + 2500
	function Nul-Widths { @(((Send $script:sc $SCI.POINTX 0 ($short + 1)) - (Send $script:sc $SCI.POINTX 0 $short)), ((Send $script:sc $SCI.POINTX 0 ($long + 1)) - (Send $script:sc $SCI.POINTX 0 $long))) }
	$shown = Nul-Widths # the long line's layout fills the table
	[void](Send $script:main 0x0111 $IDM_VIEW_NPC_CCUNIEOL); $hidden = Nul-Widths
	Check 'hidden control characters (Show Control Characters off): still no width with the grid on, on a short line and one over 2,000 bytes' (($hidden -join ',') -eq '0,0') "NUL: shown $($shown -join ' / ') px, hidden $($hidden -join ' / ') px"
	[void](Send $script:main 0x0111 $IDM_VIEW_NPC_CCUNIEOL); $again = Nul-Widths; $cell = Get-Cell
	Check '  shown again: the same label on both lines, in whole cells' ($again[0] -gt 0 -and $again[0] -eq $again[1] -and (On-Grid $again[0] $cell)) ("NUL $($again -join ' / ') px, cell {0:N2} px" -f $cell)
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) # off: the caret's x where the tab stop puts it
	$c = (Send $script:sc $SCI.POSITIONFROMLINE 3) + 3; [void](Send $script:sc 2025 $c); [void](Send $script:sc 2399) # SCI_GOTOPOS, SCI_CHOOSECARETX
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID); [void](Send $script:sc 2300) # on, SCI_LINEDOWN
	$column = (Send $script:sc 2008) - (Send $script:sc $SCI.POSITIONFROMLINE 4) # SCI_GETCURRENTPOS
	Check 'Down after the grid is turned on: below where the caret is now ("ab<TAB>c": column 6, not the tab stop''s 4)' ($column -eq 6) "column $column"
	$cell = Get-Cell
	$xPixels = foreach ($line in 5..12) {
		$start = Send $script:sc $SCI.POSITIONFROMLINE $line; $x = (Send $script:sc $SCI.GETLINEENDPOSITION $line) - 1 # the x, last before the line end
		(Send $script:sc $SCI.POINTX 0 $x) - (Send $script:sc $SCI.POINTX 0 $start)
	}
	$xCells = $xPixels | ForEach-Object { [Math]::Round($_ / $cell) }
	$onGrid = @($xPixels | Where-Object { -not (On-Grid $_ $cell) }).Count -eq 0
	$expected = '2,1,2,2,4,2,2,' + ((Send $script:sc $SCI.GETTABWIDTH) + 1)
	Check 'Unicode''s widths: half-width katakana 1 cell, a combining accent 0, U+2764 U+FE0F 2, an emoji 2, an emoji with its skin tone 4 (its parts), a keycap 2, a decomposed Hangul syllable 2, a combining accent after a tab 1' ((($xCells -join ',') -eq $expected) -and $onGrid) ("the x after each at cell $($xCells -join ', ') ($($xPixels -join ', ') px, cell {0:N2})" -f $cell)
	# the RLO hidden (Show Non-Printing Characters off; the settings may keep it on): "ab cd ef" compared from its a
	if (([CG.U]::GetMenuState([CG.U]::GetMenu($script:main), $IDM_VIEW_NPC, 0) -band 8) -ne 0) { [void](Send $script:main 0x0111 $IDM_VIEW_NPC) }
	$a13 = Send $script:sc $SCI.POSITIONFROMLINE 13; $a14 = (Send $script:sc $SCI.POSITIONFROMLINE 14) + 3
	$rloWidth = (Send $script:sc $SCI.POINTX 0 $a14) - (Send $script:sc $SCI.POINTX 0 ($a14 - 3))
	$reordered = foreach ($tech in 1, 0) { [void](Send $script:sc $SCI.SETTECHNOLOGY $tech); Start-Sleep -Milliseconds 400; Different-Pixels $a13 $a14 8 }
	# the comparison sees a reordering: without the grid, Scintilla draws the text after the RLO right to left
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID)
	$scintillaOwn = foreach ($tech in 1, 0) { [void](Send $script:sc $SCI.SETTECHNOLOGY $tech); Start-Sleep -Milliseconds 400; Different-Pixels $a13 $a14 8 }
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID)
	Check 'a hidden RLO (U+202E) reorders nothing: "ab cd ef" after it drawn as without it, DirectWrite and GDI' (($reordered -join ',') -eq '0,0' -and $rloWidth -eq 0 -and @($scintillaOwn | Where-Object { $_ -gt 0 }).Count -eq 2) "pixels that differ: $($reordered -join ' / ') (without the grid, reordered: $($scintillaOwn -join ' / ')); the RLO $rloWidth px wide"
	# whole-pixel cells: with DirectWrite, at a zoom where Consolas' advance is well between two pixels, each 0 of the line
	# drawn alike with the grid (without it, as many ways as the phases of the pixel each starts in: the check sees them)
	[void](Send $script:sc $SCI.SETTECHNOLOGY 1)
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) # off
	$zoom = 0; $advance = 0
	foreach ($z in 0, 1, 2, 3, -1, 4, 5, -2, 6, 7) {
		[void](Send $script:sc $SCI.SETZOOM $z); $advance = Get-Cell
		if ((($advance - [Math]::Floor($advance)) -gt 0.25) -and (($advance - [Math]::Floor($advance)) -lt 0.75)) { $zoom = $z; break }
	}
	# the line's characters from the first counted (a box drawing line reaches into the next cell: from the second)
	function Line-Renderings([int] $line, [int] $from = 0) { # the cell measured on line 0, then the line scrolled to the top (zoomed, it's low)
		$w = [int][Math]::Floor((Get-Cell)); [void](Send $script:sc 2613 $line); Start-Sleep -Milliseconds 400 # SCI_SETFIRSTVISIBLELINE
		$capture = Get-Capture; $start = Send $script:sc $SCI.POSITIONFROMLINE $line
		$n = @($from..23 | ForEach-Object { Cell-Pixels $capture (Send $script:sc 2670 $start $_) $w (Send $script:sc 2279 $line) } | Sort-Object -Unique).Count
		$capture.Bitmap.Dispose(); [void](Send $script:sc 2613 0); $n
	}
	$kindsOff = Line-Renderings 15; $boxKindsOff = Line-Renderings 16 1; $quoteKindsOff = Line-Renderings 17
	[void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) # on
	$cell = Get-Cell; $kinds = Line-Renderings 15; $boxKinds = Line-Renderings 16 1; $quoteKinds = Line-Renderings 17
	[void](Send $script:sc $SCI.SETZOOM 0)
	Check 'DirectWrite: the cell a whole number of pixels, and each 0 of a line drawn alike in its cell' (($cell -eq [Math]::Round($cell)) -and ($kinds -eq 1) -and ($kindsOff -gt 1)) ("zoom {0}: Consolas' advance {1:N3} px, the cell {2} px; 24 zeros drawn {3} way(s) (without the grid: {4})" -f $zoom, $advance, $cell, $kinds, $kindsOff)
	Check '  each box drawing line (U+2500) and each quote (U+201C) of a line too (drawn in a batch)' (($boxKinds -eq 1) -and ($quoteKinds -eq 1) -and ($boxKindsOff -gt 1) -and ($quoteKindsOff -gt 1)) "24 box lines drawn $boxKinds way(s), 24 quotes $quoteKinds (without the grid: $boxKindsOff, $quoteKindsOff)"
	Stop-Npp $p

	# --- an ANSI document: every byte one cell, also those the font gives no width (C1 controls in windows-1252); in GBK
	# (a DBCS code page, only on a CJK Windows: set directly), a double-byte character two
	$cpFile = Join-Path $root 'codepages.txt'
	[IO.File]::WriteAllBytes($cpFile, [byte[]]((@(0x20) * 160) + 0x58 + 0x0D + 0x0A + 0x61 + 0xD6 + 0xD0 + 0x62 + 0x0D + 0x0A + 0x61 + 0x81 + 0x8D + 0x8F + 0x90 + 0x9D + 0x62 + 0x0D + 0x0A))
	$p = Start-Npp 'Consolas' $cpFile
	if (-not (Grid-On)) { [void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) }
	if ((Send $script:sc 2137) -ne 0) { [void](Send $script:main 0x0111 45004); Start-Sleep -Milliseconds 400 } # IDM_FORMAT_ANSI
	$l1 = Send $script:sc $SCI.POSITIONFROMLINE 1; $l2 = Send $script:sc $SCI.POSITIONFROMLINE 2
	if (((Send $script:sc 2137) -eq 0) -and ((Send $script:sc $SCI.GETCHARAT ($l2 + 1)) -band 0xFF) -eq 0x81) {
		$cell = Get-Cell
		$ansiX = (Send $script:sc $SCI.POINTX 0 ($l2 + 6)) - (Send $script:sc $SCI.POINTX 0 $l2)
		[void](Send $script:sc 2037 936); Start-Sleep -Milliseconds 300 # SCI_SETCODEPAGE
		$gbkX = (Send $script:sc $SCI.POINTX 0 ($l1 + 3)) - (Send $script:sc $SCI.POINTX 0 $l1)
		$ansiB = [Math]::Round($ansiX / $cell); $gbkB = [Math]::Round($gbkX / $cell)
		Check 'ANSI (windows-1252): every byte one cell, C1 controls 81 8D 8F 90 9D too; GBK: a double-byte character two (D6 D0)' (($ansiB -eq 6) -and ($gbkB -eq 3) -and (On-Grid $ansiX $cell) -and (On-Grid $gbkX $cell)) ("ANSI: the b after five bytes at cell $ansiB ($ansiX px); GBK: the b after one character at cell $gbkB ($gbkX px), cell {0:N2}" -f $cell)
	}
	else { Info "the code page file didn't open as ANSI (code page $(Send $script:sc 2137)): the ANSI and GBK check skipped" }
	Stop-Npp $p

	# --- virtual space in a proportional font: a space of every style a cell (Segoe UI's space is narrower than its "0")
	$vsFile = Join-Path $root 'virtual.txt'; [IO.File]::WriteAllText($vsFile, ($gridLines[0] + "`r`nabcdef`r`na`r`n"), $utf8)
	$p = Start-Npp 'Segoe UI' $vsFile
	if (-not (Grid-On)) { [void](Send $script:main 0x0111 $IDM_VIEW_CHARACTER_GRID) }
	# SCI_SETVIRTUALSPACEOPTIONS (rectangular selection, and the keys too: Preferences' virtual space), SCI_GOTOPOS,
	# SCI_CHOOSECARETX, SCI_LINEDOWNRECTEXTEND
	[void](Send $script:sc 2596 3); [void](Send $script:sc 2025 (Send $script:sc $SCI.GETLINEENDPOSITION 1)); [void](Send $script:sc 2399); [void](Send $script:sc 2426)
	$virtual = Send $script:sc 2593 # SCI_GETRECTANGULARSELECTIONCARETVIRTUALSPACE
	Check 'Segoe UI: a rectangular selection down from the end of "abcdef" to "a" ends in the same cell (5 cells of virtual space)' ($virtual -eq 5) "virtual space: $virtual"
	Stop-Npp $p
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
