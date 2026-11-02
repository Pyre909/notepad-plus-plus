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
# representations change); Down after a toggle goes below where the caret is now. Not driven: printing (printed without
# it), the edge's background mode and the labels' centring (pixels only).
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
'@
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Info([string] $text) { $script:results.Add("INFO  $text") }
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][CG.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }
$IDM_VIEW_CHARACTER_GRID = 44190; $IDM_VIEW_ALL_CHARACTERS = 44019; $IDM_VIEW_GOTO_ANOTHER_VIEW = 10001; $IDM_VIEW_NPC_CCUNIEOL = 44131
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
	$cjkOff = Test-Lines ($cjkFirst..($cjkFirst + $cjkLines.Count - 1)) (Get-Cell)
	Info ("Consolas has no CJK: its CJK comes from another font, {0} characters off the grid (a 2:1 font puts them on it)" -f $cjkOff.Count)
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
	$cell = Get-Cell; $bad = Test-Lines $monoLines $cell -OnlyTabsAndReps
	Check 'Segoe UI (proportional): tabs one tab size wide, representations in whole cells, letters as the font makes them' ($bad.Count -eq 0) $(if ($bad) { ($bad | Select-Object -First 4) -join '; ' } else { "cell {0:N2} px" -f $cell })
	Stop-Npp $p

	# --- hidden control characters, a line over 2,000 bytes (Scintilla's table of control characters' widths), the caret
	$ccFile = Join-Path $root 'control.txt'
	[IO.File]::WriteAllText($ccFile, ($gridLines[0] + "`r`na" + [char]0 + "b`r`n" + ('x' * 2500) + [char]0 + "b`r`nab${T}c`r`n0123456789`r`n"), $utf8)
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
	Stop-Npp $p
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
