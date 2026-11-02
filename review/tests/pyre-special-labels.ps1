# App-level test (review harness), Pyre909 builds only: the labels of special characters. One style for all: a box with
# rounded corners spanning most of the line's height (Scintilla's DrawTextBlob), a font of its own (STYLE_CONTROLCHAR:
# Segoe UI Semibold, three quarters of the text's size); a colour by kind (control characters, line ends, invisible
# characters, invalid bytes) in tones for the theme's background; Unicode's names (BOM, not ZWNBSP) and the invisible
# characters Notepad++ didn't label (CGJ, FVS1, fillers, musical and shorthand formatting, the language tag). The colours
# kept after a document switch, the symbols hidden and shown again and an encoding change; Preferences' custom colours
# (non-printing characters, with or without the control characters; line ends) still win. Checked through the
# representations (SCI_GETREPRESENTATION*, through memory in the process) and the pixels of a label (DirectWrite, GDI).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace SL -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
[DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
[DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr m, uint id, uint flags);
[DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
[DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, UIntPtr size, uint type, uint protect);
[DllImport("kernel32.dll")] public static extern bool VirtualFreeEx(IntPtr p, IntPtr a, UIntPtr size, uint type);
[DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] b, UIntPtr size, out UIntPtr written);
[DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, UIntPtr size, out UIntPtr read);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
'@
[void][SL.U]::SetThreadDpiAwarenessContext([IntPtr](-4)) # per-monitor v2: rectangles in the pixels PrintWindow draws
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Info([string] $text) { $script:results.Add("INFO  $text") }
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][SL.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }
$IDM = @{ ALL_CHARACTERS = 44019; NPC = 44130; CCUNIEOL = 44131; TAB_NEXT = 44095; TAB_PREV = 44096; ANSI = 45004; UTF8 = 45008 }

# the colours by kind: [ColourRGBA] as Scintilla returns it (0xAABBGGRR), for a light and a dark background
function Rgba([int] $r, [int] $g, [int] $b) { [int64](0xFF000000L -bor ($b -shl 16) -bor ($g -shl 8) -bor $r) }
$tones = @{
	light = @{ control = (Rgba 0x3B 0x4A 0x63); lineEnd = (Rgba 0x24 0x6E 0x68); invisible = (Rgba 0x6A 0x3F 0xA0); invalid = (Rgba 0xB3 0x26 0x1E) }
	dark = @{ control = (Rgba 0x9D 0xB2 0xD3); lineEnd = (Rgba 0x6C 0xC3 0xBA); invisible = (Rgba 0xC4 0xA6 0xF0); invalid = (Rgba 0xF2 0x8B 0x82) }
}

# the special characters (UTF-8 bytes), the files (UTF-8 with a BOM, so the bad bytes stay invalid bytes)
$k = @{ NUL = [byte[]](0); ESC = [byte[]](0x1B); DEL = [byte[]](0x7F); NBSP = [byte[]](0xC2, 0xA0); ZWSP = [byte[]](0xE2, 0x80, 0x8B)
	BOM = [byte[]](0xEF, 0xBB, 0xBF); CGJ = [byte[]](0xCD, 0x8F); FVS1 = [byte[]](0xE1, 0xA0, 0x8B); HF = [byte[]](0xE3, 0x85, 0xA4)
	BEAM = [byte[]](0xF0, 0x9D, 0x85, 0xB3); TAG = [byte[]](0xF3, 0xA0, 0x80, 0x81); NEL = [byte[]](0xC2, 0x85); LS = [byte[]](0xE2, 0x80, 0xA8)
	CR = [byte[]](0x0D); LF = [byte[]](0x0A); xE9 = [byte[]](0xE9); xFF = [byte[]](0xFF) }
$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-special-labels-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $root | Out-Null
function Write-Sample([string] $name, [object[]] $parts) {
	$bytes = [Collections.Generic.List[byte]]::new(); $bytes.AddRange([byte[]](0xEF, 0xBB, 0xBF))
	foreach ($p in $parts) { if ($p -is [string]) { $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($p)) } else { $bytes.AddRange([byte[]]$p) } }
	$path = Join-Path $root $name; [IO.File]::WriteAllBytes($path, $bytes.ToArray()); $path
}
$file = Write-Sample 'labels.txt' @('ESC[', $k.ESC, '] NUL[', $k.NUL, '] DEL[', $k.DEL, "]`r`n",
	'NBSP[', $k.NBSP, '] ZWSP[', $k.ZWSP, '] BOM[', $k.BOM, '] CGJ[', $k.CGJ, '] FVS1[', $k.FVS1, '] HF[', $k.HF, '] BEAM[', $k.BEAM, '] TAG[', $k.TAG, "]`r`n",
	'NEL[', $k.NEL, '] LS[', $k.LS, "]`r`n", 'Bad[', $k.xE9, '] [', $k.xFF, "]`r`n")
$second = Write-Sample 'second.txt' @('Second', $k.NBSP, 'document [', $k.xE9, "]`r`n")

function Start-Npp([string] $name, [string] $themeFile = '') {
	$settings = Join-Path $root $name; New-Item -ItemType Directory -Force $settings | Out-Null
	if (-not (Test-Path (Join-Path $settings 'stylers.xml'))) {
		$model = [IO.File]::ReadAllText($(if ($themeFile) { $themeFile } else { Join-Path (Split-Path $Exe) 'stylers.model.xml' }))
		$model = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32"[^>]*?fontName=")[^"]*("[^>]*?fontSize=")[^"]*"', "`${1}Consolas`${2}10`"")
		[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model, [Text.UTF8Encoding]::new($false))
	}
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', "`"$second`"", "`"$file`"" -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	$script:main = $p.MainWindowHandle; $script:settings = $settings
	$h = [IntPtr]::Zero; $script:sc = [IntPtr]::Zero
	while (($h = [SL.U]::FindWindowEx($script:main, $h, 'Scintilla', [NullString]::Value)) -ne [IntPtr]::Zero) { if ($script:sc -eq [IntPtr]::Zero -and [SL.U]::IsWindowVisible($h)) { $script:sc = $h } }
	$script:proc = [SL.U]::OpenProcess(0x0438, $false, $p.Id); $script:mem = [SL.U]::VirtualAllocEx($script:proc, [IntPtr]::Zero, [UIntPtr]512, 0x3000, 4)
	if (([SL.U]::GetMenuState([SL.U]::GetMenu($script:main), $IDM.ALL_CHARACTERS, 0) -band 8) -eq 0) { [void](Send $script:main 0x0111 $IDM.ALL_CHARACTERS) } # a toggle, saved
	$p
}
function Stop-Npp($p, [switch] $Kill) {
	[void][SL.U]::VirtualFreeEx($script:proc, $script:mem, [UIntPtr]::Zero, 0x8000); [void][SL.U]::CloseHandle($script:proc)
	if ($Kill) { Stop-Process -Id $p.Id -Force; [void]$p.WaitForExit(5000); return } # a modified document: no save prompt
	[void][SL.U]::PostMessage($script:main, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force }
}
function Put([byte[]] $bytes) { $w = [UIntPtr]::Zero; [void][SL.U]::WriteProcessMemory($script:proc, $script:mem, ([byte[]]$bytes + [byte]0), [UIntPtr]($bytes.Length + 1), [ref]$w) }
function Text-At([long] $offset, [long] $length) {
	if ($length -le 0) { return '' }
	$buf = [byte[]]::new($length); $r = [UIntPtr]::Zero; [void][SL.U]::ReadProcessMemory($script:proc, [IntPtr]([Int64]$script:mem + $offset), $buf, [UIntPtr]$length, [ref]$r)
	[Text.Encoding]::UTF8.GetString($buf)
}
# a representation's text, colour (0xAABBGGRR) and appearance; NUL's key is the empty string
function Repr-Text([byte[]] $key) { Put ($(if ($key[0] -eq 0) { [byte[]]@() } else { $key })); Text-At 256 (Send $script:sc 2666 ([Int64]$script:mem) ([Int64]$script:mem + 256)) }
function Repr-Colour([byte[]] $key) { Put ($(if ($key[0] -eq 0) { [byte[]]@() } else { $key })); (Send $script:sc 2769 ([Int64]$script:mem)) -band 0xFFFFFFFFL }
function Repr-Appearance([byte[]] $key) { Put ($(if ($key[0] -eq 0) { [byte[]]@() } else { $key })); Send $script:sc 2767 ([Int64]$script:mem) }
function Hex([int64] $v) { '{0:X8}' -f $v }
# the keys whose colour isn't the expected one
function Wrong-Colours([hashtable] $expected) { @($expected.Keys | Where-Object { (Repr-Colour $k[$_]) -ne $expected[$_] } | ForEach-Object { "$_ $(Hex (Repr-Colour $k[$_])) not $(Hex $expected[$_])" }) }
function Kind-Map([hashtable] $t) {
	@{ ESC = $t.control; NUL = $t.control; DEL = $t.control; NEL = $t.lineEnd; LS = $t.lineEnd; CR = $t.lineEnd; LF = $t.lineEnd
		NBSP = $t.invisible; ZWSP = $t.invisible; BOM = $t.invisible; CGJ = $t.invisible; TAG = $t.invisible; xE9 = $t.invalid; xFF = $t.invalid }
}
# the share of a label's line height that its box fills: the rows of its cell holding pixels of the colour
function Box-Rows([long] $pos, [int64] $rgba) {
	$rm = [SL.U+RECT]::new(); [void][SL.U]::GetWindowRect($script:main, [ref]$rm); $pt = [SL.U+POINT]::new(); [void][SL.U]::ClientToScreen($script:sc, [ref]$pt)
	$bmp = [Drawing.Bitmap]::new($rm.Right - $rm.Left, $rm.Bottom - $rm.Top); $g = [Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc(); [void][SL.U]::PrintWindow($script:main, $hdc, 2); $g.ReleaseHdc($hdc); $g.Dispose()
	$x1 = (Send $script:sc 2164 0 $pos) + $pt.X - $rm.Left; $x2 = (Send $script:sc 2164 0 ($pos + 1)) + $pt.X - $rm.Left
	$y1 = (Send $script:sc 2165 0 $pos) + $pt.Y - $rm.Top; $height = Send $script:sc 2279 (Send $script:sc 2166 $pos)
	$want = [Drawing.Color]::FromArgb(255, $rgba -band 0xFF, ($rgba -shr 8) -band 0xFF, ($rgba -shr 16) -band 0xFF)
	$rows = 0
	for ($y = $y1; $y -lt $y1 + $height; $y++) {
		for ($x = $x1 + 2; $x -lt $x2 - 2; $x++) { $c = $bmp.GetPixel($x, $y); if ($c.R -eq $want.R -and $c.G -eq $want.G -and $c.B -eq $want.B) { $rows++; break } }
	}
	$bmp.Dispose(); [double]$rows / $height
}

try {
	# --- light theme (stylers.model.xml), Consolas
	$p = Start-Npp 'light'
	$names = @{ BOM = 'BOM'; CGJ = 'CGJ'; FVS1 = 'FVS1'; HF = 'U+3164'; BEAM = 'U+1D173'; TAG = 'U+E0001'; ESC = 'ESC'; NUL = 'NUL'; NEL = 'NEL'; xE9 = 'xE9' }
	$badNames = @($names.Keys | Where-Object { (Repr-Text $k[$_]) -ne $names[$_] } | ForEach-Object { "$_ '$(Repr-Text $k[$_])'" })
	Check 'names: BOM (not ZWNBSP), the invisible characters Notepad++ missed (CGJ, FVS1, U+3164, U+1D173, U+E0001), the others as before' ($badNames.Count -eq 0) ($badNames -join '; ')
	$light = Kind-Map $tones.light
	$wrong = Wrong-Colours $light
	$appear = @($light.Keys | Where-Object { (Repr-Appearance $k[$_]) -ne 0x11 })
	Check 'light theme: a colour by kind (control characters, line ends, invisible characters, invalid bytes), drawn as boxes (appearance blob + colour)' ($wrong.Count -eq 0 -and $appear.Count -eq 0) $(if ($wrong -or $appear) { (@($wrong) + @($appear | ForEach-Object { "$_ appearance $(Repr-Appearance $k[$_])" })) -join '; ' } else { '' })
	$len = Send $script:sc 2486 36 ([Int64]$script:mem + 256); $font = Text-At 256 $len
	$weight = Send $script:sc 2064 36; $size = Send $script:sc 2062 36; $defaultSize = Send $script:sc 2062 32
	Check 'the labels'' font: Segoe UI Semibold (or Segoe UI at weight 600 with DirectWrite), three quarters of the text''s size' (($font -eq 'Segoe UI Semibold' -or ($font -eq 'Segoe UI' -and $weight -eq 600)) -and $size -eq [Math]::Floor($defaultSize * 3 / 4)) "font '$font', weight $weight, size $size of $defaultSize"
	$escPos = (Send $script:sc 2167 0) + 4
	foreach ($tech in @(@(1, 'DirectWrite'), @(0, 'GDI'))) {
		[void](Send $script:sc 2630 $tech[0]); Start-Sleep -Milliseconds 400
		$share = Box-Rows $escPos $tones.light.control
		Check "  $($tech[1]): ESC's box spans at least three quarters of the line's height (a label, not the text-high blob)" ($share -ge 0.75) ("{0:P0} of the line" -f $share)
	}
	[void](Send $script:sc 2630 1)
	[void](Send $script:main 0x0111 $IDM.TAB_PREV); Start-Sleep -Milliseconds 400
	$wrong = Wrong-Colours @{ NBSP = $tones.light.invisible; xE9 = $tones.light.invalid; CR = $tones.light.lineEnd }
	[void](Send $script:main 0x0111 $IDM.TAB_NEXT); Start-Sleep -Milliseconds 400
	$wrong += Wrong-Colours @{ ESC = $tones.light.control; xFF = $tones.light.invalid }
	Check '  kept after a switch to the other document and back' ($wrong.Count -eq 0) ($wrong -join '; ')
	foreach ($id in $IDM.NPC, $IDM.NPC, $IDM.CCUNIEOL, $IDM.CCUNIEOL) { [void](Send $script:main 0x0111 $id) }
	$wrong = Wrong-Colours $light
	Check '  kept after Show Non-Printing Characters and Show Control Characters hidden and shown again' ($wrong.Count -eq 0) ($wrong -join '; ')
	[void](Send $script:main 0x0111 $IDM.ANSI); Start-Sleep -Milliseconds 400; [void](Send $script:main 0x0111 $IDM.UTF8); Start-Sleep -Milliseconds 400
	$wrong = Wrong-Colours $light
	Check '  kept after Encoding > ANSI and back to UTF-8 (the representations set again)' ($wrong.Count -eq 0) ($wrong -join '; ')
	Stop-Npp $p -Kill

	# --- custom colours of Preferences: non-printing characters (then with the control characters), line ends; the
	# options set in the config.xml of a first start
	$p = Start-Npp 'custom'; Stop-Npp $p
	$config = Join-Path $script:settings 'config.xml'
	$xml = [IO.File]::ReadAllText($config) -replace 'npcCustomColor="no"', 'npcCustomColor="yes"' -replace 'eolMode="1"', 'eolMode="3"'
	[IO.File]::WriteAllText($config, $xml, [Text.UTF8Encoding]::new($false))
	$p = Start-Npp 'custom'
	$npcCustom = Rgba 0xFF 0xB5 0x6A; $eolCustom = Rgba 0xDA 0xDA 0xDA
	$wrong = Wrong-Colours @{ NBSP = $npcCustom; BOM = $npcCustom; ESC = $tones.light.control; CR = $eolCustom; xE9 = $tones.light.invalid }
	Check 'custom colours win: the non-printing characters'' (FFB56A), the line ends'' (DADADA); control characters and invalid bytes by kind' ($wrong.Count -eq 0) ($wrong -join '; ')
	Stop-Npp $p
	$xml = [IO.File]::ReadAllText($config) -replace 'npcIncludeCcUniEOL="no"', 'npcIncludeCcUniEOL="yes"'
	[IO.File]::WriteAllText($config, $xml, [Text.UTF8Encoding]::new($false))
	$p = Start-Npp 'custom'
	$wrong = Wrong-Colours @{ ESC = $npcCustom; NEL = $npcCustom; NBSP = $npcCustom }
	Check '  with "apply to C0, C1 and Unicode EOL": the control characters in the custom colour too' ($wrong.Count -eq 0) ($wrong -join '; ')
	Stop-Npp $p

	# --- a dark theme: light tones, the label's text the background's colour
	$dark = @((Join-Path (Split-Path $Exe) 'themes\DarkModeDefault.xml'), (Join-Path (Split-Path $Exe) '..\installer\themes\DarkModeDefault.xml')) | Where-Object { Test-Path $_ } | Select-Object -First 1
	if ($dark) {
		$p = Start-Npp 'dark' $dark
		$wrong = Wrong-Colours (Kind-Map $tones.dark)
		Check 'dark theme (DarkModeDefault): the light tones of each kind' ($wrong.Count -eq 0) ($wrong -join '; ')
		$share = Box-Rows ((Send $script:sc 2167 0) + 4) $tones.dark.control
		Check '  ESC''s box drawn in its tone, three quarters of the line high' ($share -ge 0.75) ("{0:P0} of the line" -f $share)
		Stop-Npp $p
	}
	else { Info 'DarkModeDefault.xml not found beside the build: the dark theme checks skipped' }
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
