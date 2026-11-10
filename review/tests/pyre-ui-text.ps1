# App-level test (review harness), Pyre909 builds only: the text Notepad++ draws itself drawn with DirectWrite while the
# editor is (drawUiText, 2026-11-10). Three files and the Function List open, the window 1100x560 pixels: with the
# editor on DirectWrite the tab strip and the panel's caption are drawn otherwise than with GDI (a config.xml of GDI,
# offered), their text where GDI puts it (its top and bottom rows within a pixel, its left column within one); dark mode:
# the status bar too (light mode: Windows draws it, as before); vertical tabs (a rotated font) left to GDI. Live:
# DirectWrite chosen in Preferences > Editing 1 draws the tab strip as a DirectWrite start does, without restarting;
# Grayscale antialiasing draws its text without ClearType's colours. The Ctrl+Tab list, Antialiasing None, its selection
# moved (painted again in part, its DC shifted): its text in two colours, DirectWrite's aliased text all over.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class UT {
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
	[DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
	[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
	[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
	[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
[void][UT]::SetProcessDpiAwarenessContext([IntPtr](-4))
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $CB_SETCURSEL = 0x014E
$IDM_SETTING_PREFERENCE = 48011; $IDM_VIEW_SWITCHTO_FUNC_LIST = 44108; $IDC_BTN_CAPTION = 1050
$IDC_COMBO_SC_TECHNOLOGY_CHOICE = 6362; $IDC_COMBO_TEXTANTIALIASING = 6282

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][UT]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][UT]::EnumWindows({ param($h, $l) $p = 0; [void][UT]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	$script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][UT]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids.ToArray()
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][UT]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Get-Rect([IntPtr] $h) { $r = [UT+RECT]::new(); [void][UT]::GetWindowRect($h, [ref]$r); $r }

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-ui-text-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $root | Out-Null
$files = foreach ($n in 'FontFamilyNames.cpp', 'STATUS.md', 'notes & ideas.txt') { $p = Join-Path $root $n; [IO.File]::WriteAllText($p, "int main() { return 0; }`r`n"); $p }

# starts Notepad++ (technology 1 DirectWrite, 0 GDI, offered), the Function List shown; the main window's parts: the tab
# strip (the tab bar above the edit view, or left of it with vertical tabs), the panel's caption, the status bar
function Start-Npp([string] $name, [int] $technology, [bool] $isDark, [string] $tabBar = '', [string] $viewParams = '') {
	$settings = Join-Path $root $name; New-Item -ItemType Directory -Force $settings | Out-Null
	$dark = if ($isDark) { 'yes' } else { 'no' }
	$tabBarConfig = if ($tabBar) { '<GUIConfig name="TabBar" ' + $tabBar + ' />' } else { '' }
	if ($viewParams) { $tabBarConfig += '<GUIConfig name="ScintillaPrimaryView" ' + $viewParams + ' />' }
	[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), "<?xml version=""1.0"" encoding=""UTF-8"" ?><NotepadPlus><GUIConfigs><GUIConfig name=""DarkMode"" enable=""$dark"" /><GUIConfig name=""MISC"" writeTechnologyEngine=""$technology"" offerGdiRendering=""yes"" />$tabBarConfig</GUIConfigs></NotepadPlus>")
	$script:runName = $name; $script:shotIndex = 0
	$script:proc = Start-Process $Exe -ArgumentList (@('-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST') + ($files | ForEach-Object { "`"$_`"" })) -PassThru
	$script:npid = $script:proc.Id
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 1000
	[void][UT]::MoveWindow($script:main, 40, 40, 1100, 560, $true)
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_SWITCHTO_FUNC_LIST); Start-Sleep -Milliseconds 1200 # shown and focused: its caption active in every run
}
function Stop-Npp {
	if (-not $script:proc.HasExited) { [void][UT]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
}
function Get-Parts {
	$w = Get-Rect $script:main
	$kids = Get-Kids $script:main | Where-Object { [UT]::IsWindowVisible($_) }
	$tab = $kids | Where-Object { (Get-Cls $_) -eq 'SysTabControl32' -and ([UT]::GetParent($_) -eq $script:main) } | ForEach-Object { Get-Rect $_ } | Sort-Object Left, Top | Select-Object -First 1
	$view = $kids | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and ([UT]::GetParent($_) -eq $script:main) } | ForEach-Object { Get-Rect $_ } | Sort-Object Left, Top | Select-Object -First 1
	$caption = $kids | Where-Object { [UT]::GetDlgCtrlID($_) -eq $IDC_BTN_CAPTION } | ForEach-Object { Get-Rect $_ } | Select-Object -First 1
	$status = $kids | Where-Object { (Get-Cls $_) -eq 'msctls_statusbar32' } | ForEach-Object { Get-Rect $_ } | Select-Object -First 1
	$parts = [ordered]@{}
	if ($tab -and $view) {
		$parts['tabs'] = if ($view.Top - $tab.Top -gt 8) { [Drawing.Rectangle]::new($tab.Left - $w.Left, $tab.Top - $w.Top, $tab.Right - $tab.Left, $view.Top - $tab.Top) }
			else { [Drawing.Rectangle]::new($tab.Left - $w.Left, $tab.Top - $w.Top, $view.Left - $tab.Left, $tab.Bottom - $tab.Top) }
	}
	if ($caption) { $parts['caption'] = [Drawing.Rectangle]::new($caption.Left - $w.Left, $caption.Top - $w.Top, $caption.Right - $caption.Left, $caption.Bottom - $caption.Top) }
	if ($status) { $parts['status'] = [Drawing.Rectangle]::new($status.Left - $w.Left, $status.Top - $w.Top, [Math]::Min(500, $status.Right - $status.Left), $status.Bottom - $status.Top) }
	$parts
}
# the window as drawn (PW_RENDERFULLCONTENT), its parts cropped
function Get-Shot {
	$w = Get-Rect $script:main
	$bmp = [Drawing.Bitmap]::new([int]($w.Right - $w.Left), [int]($w.Bottom - $w.Top)); $g = [Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
	[void][UT]::PrintWindow($script:main, $hdc, 2); $g.ReleaseHdc($hdc); $g.Dispose()
	$crops = @{}
	$parts = Get-Parts
	foreach ($k in $parts.Keys) { $crops[$k] = $bmp.Clone($parts[$k], [Drawing.Imaging.PixelFormat]::Format32bppArgb) }
	$script:shotIndex++
	foreach ($k in $crops.Keys) { $crops[$k].Save((Join-Path $root "$($script:runName)-$($script:shotIndex)-$k.png")) } # for a failure's look
	$bmp.Dispose()
	$crops
}
function Get-Pixels([Drawing.Bitmap] $b) {
	$data = $b.LockBits([Drawing.Rectangle]::new(0, 0, $b.Width, $b.Height), 'ReadOnly', [Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$px = [int[]]::new($b.Width * $b.Height); [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $px, 0, $px.Length); $b.UnlockBits($data); $px
}
# pixels that differ, and the box of those (the text: what the two draw otherwise)
function Compare-Crops([Drawing.Bitmap] $a, [Drawing.Bitmap] $b) {
	if (-not $a -or -not $b -or ($a.Width -ne $b.Width) -or ($a.Height -ne $b.Height)) { return [pscustomobject]@{ Count = -1 } }
	$pa = Get-Pixels $a; $pb = Get-Pixels $b; $n = 0; $x0 = $a.Width; $y0 = $a.Height; $x1 = -1; $y1 = -1
	for ($i = 0; $i -lt $pa.Length; $i++) {
		if (($pa[$i] -band 0xFFFFFF) -ne ($pb[$i] -band 0xFFFFFF)) {
			$n++; $x = $i % $a.Width; $y = [Math]::Floor($i / $a.Width)
			$x0 = [Math]::Min($x0, $x); $x1 = [Math]::Max($x1, $x); $y0 = [Math]::Min($y0, $y); $y1 = [Math]::Max($y1, $y)
		}
	}
	[pscustomobject]@{ Count = $n; Box = [Drawing.Rectangle]::new($x0, $y0, $x1 - $x0 + 1, $y1 - $y0 + 1) }
}
# the ink of the text within a box: its top, bottom and left rows/columns (pixels far from the box's commonest colour)
function Get-Ink([Drawing.Bitmap] $b, [Drawing.Rectangle] $box) {
	$px = Get-Pixels $b
	$counts = @{}; for ($y = $box.Top; $y -lt $box.Bottom; $y++) { for ($x = $box.Left; $x -lt $box.Right; $x++) { $counts[$px[$y * $b.Width + $x]]++ } }
	$back = ($counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
	$lum = { param($c) (($c -shr 16) -band 0xFF) * 299 + (($c -shr 8) -band 0xFF) * 587 + ($c -band 0xFF) * 114 }
	$backLum = & $lum $back; $top = $box.Bottom; $bottom = -1; $left = $box.Right
	for ($y = $box.Top; $y -lt $box.Bottom; $y++) { for ($x = $box.Left; $x -lt $box.Right; $x++) {
		if ([Math]::Abs((& $lum $px[$y * $b.Width + $x]) - $backLum) -gt 90000) { $top = [Math]::Min($top, $y); $bottom = [Math]::Max($bottom, $y); $left = [Math]::Min($left, $x) }
	} }
	[pscustomobject]@{ Top = $top; Bottom = $bottom; Left = $left }
}
# the coloured pixels (ClearType's fringes) of the text: where two shots of it differ (the icons alike in both)
function Get-Colored([Drawing.Bitmap] $b, [Drawing.Bitmap] $other) {
	$px = Get-Pixels $b; $po = Get-Pixels $other; $n = 0
	for ($i = 0; $i -lt $px.Length; $i++) {
		if (($px[$i] -band 0xFFFFFF) -eq ($po[$i] -band 0xFFFFFF)) { continue }
		$c = $px[$i]; $r = ($c -shr 16) -band 0xFF; $g = ($c -shr 8) -band 0xFF; $bl = $c -band 0xFF
		if (([Math]::Max($r, [Math]::Max($g, $bl)) - [Math]::Min($r, [Math]::Min($g, $bl))) -gt 24) { $n++ }
	}
	$n
}
# a Preferences combo set as a choice does (CBN_SELCHANGE)
function Set-PreferenceCombo([int] $id, [int] $index) {
	[void](Send $script:main $WM_COMMAND $IDM_SETTING_PREFERENCE)
	$page = $null
	for ($i = 0; $i -lt 50 -and -not $page; $i++) {
		Start-Sleep -Milliseconds 100
		foreach ($t in Get-Tops) { if ((Get-Cls $t) -eq '#32770') { $m = Get-Kids $t | Where-Object { [UT]::GetDlgItem($_, $id) -ne [IntPtr]::Zero } | Select-Object -First 1; if ($m) { $page = $m } } }
	}
	$combo = [UT]::GetDlgItem($page, $id)
	[void](Send $combo $CB_SETCURSEL $index); [void](Send $page $WM_COMMAND ((1 -shl 16) -bor $id) $combo.ToInt64()); Start-Sleep -Milliseconds 800
	[void](Send ([UT]::GetParent($page)) $WM_COMMAND 2 0); Start-Sleep -Milliseconds 300 # IDCANCEL: Preferences closed
}

try {
	Start-Npp 'dw-light' 1 $false; $dwLight = Get-Shot; Stop-Npp
	Start-Npp 'gdi-light' 0 $false; $gdiLight = Get-Shot
	# live: DirectWrite chosen (GDI offered: the list's second item), then Grayscale antialiasing
	Set-PreferenceCombo $IDC_COMBO_SC_TECHNOLOGY_CHOICE 1; $switched = Get-Shot
	Set-PreferenceCombo $IDC_COMBO_TEXTANTIALIASING 3; $grayscale = Get-Shot
	Stop-Npp

	$tabs = Compare-Crops $dwLight['tabs'] $gdiLight['tabs']
	$caption = Compare-Crops $dwLight['caption'] $gdiLight['caption']
	$status = Compare-Crops $dwLight['status'] $gdiLight['status']
	Check 'DirectWrite: the tab strip and the panel''s caption drawn otherwise than with GDI; the status bar as before (Windows draws it in light mode)' (($tabs.Count -gt 50) -and ($caption.Count -gt 50) -and ($status.Count -eq 0)) "tabs $($tabs.Count), caption $($caption.Count), status $($status.Count) pixels differ"
	# the caption's text: its left part (its close button at the right)
	$captionText = if ($caption.Count -gt 0) { [Drawing.Rectangle]::Intersect($caption.Box, [Drawing.Rectangle]::new(0, 0, [int]($dwLight['caption'].Width * 0.7), $dwLight['caption'].Height)) }
	foreach ($part in @(@('tab strip', 'tabs', $tabs.Box), @('caption', 'caption', $captionText))) {
		if (-not $part[2]) { continue }
		$dwInk = Get-Ink $dwLight[$part[1]] $part[2]; $gdiInk = Get-Ink $gdiLight[$part[1]] $part[2]
		Check "  the $($part[0])'s text where GDI puts it: top, bottom and left within a pixel" (([Math]::Abs($dwInk.Top - $gdiInk.Top) -le 1) -and ([Math]::Abs($dwInk.Bottom - $gdiInk.Bottom) -le 1) -and ([Math]::Abs($dwInk.Left - $gdiInk.Left) -le 1)) "DirectWrite $($dwInk.Top)-$($dwInk.Bottom) from $($dwInk.Left), GDI $($gdiInk.Top)-$($gdiInk.Bottom) from $($gdiInk.Left)"
	}
	$live = Compare-Crops $switched['tabs'] $dwLight['tabs']
	Check 'DirectWrite chosen in Preferences: the tab strip drawn as a DirectWrite start draws it, at once' (($live.Count -ge 0) -and ($live.Count -le 20) -and ((Compare-Crops $switched['tabs'] $gdiLight['tabs']).Count -gt 50)) "$($live.Count) pixels differ from the DirectWrite start"
	if ($tabs.Count -gt 0) {
		$clearTypeColors = Get-Colored $switched['tabs'] $grayscale['tabs']; $grayColors = Get-Colored $grayscale['tabs'] $switched['tabs']
		Check '  Grayscale antialiasing: the tab strip''s text without ClearType''s colours' (($clearTypeColors -gt 20) -and ($grayColors -eq 0)) "coloured pixels: ClearType $clearTypeColors, Grayscale $grayColors"
	}

	Start-Npp 'dw-dark' 1 $true; $dwDark = Get-Shot; Stop-Npp
	Start-Npp 'gdi-dark' 0 $true; $gdiDark = Get-Shot; Stop-Npp
	$darkTabs = Compare-Crops $dwDark['tabs'] $gdiDark['tabs']; $darkStatus = Compare-Crops $dwDark['status'] $gdiDark['status']
	Check 'dark mode: the tab strip and the status bar drawn otherwise than with GDI' (($darkTabs.Count -gt 50) -and ($darkStatus.Count -gt 50)) "tabs $($darkTabs.Count), status $($darkStatus.Count) pixels differ"

	# the TabBar settings in full (one missing: the defaults)
	$verticalTabs = 'dragAndDrop="yes" drawTopBar="yes" drawInactiveTab="yes" reduce="yes" closeButton="yes" pinButton="yes" buttonsOninactiveTabs="no" showOnlyPinnedButton="no" doubleClick2Close="no" vertical="yes" multiLine="no" hide="no" quitOnEmpty="no"'
	Start-Npp 'dw-vertical' 1 $false $verticalTabs; $dwVertical = Get-Shot; Stop-Npp
	Start-Npp 'gdi-vertical' 0 $false $verticalTabs; $gdiVertical = Get-Shot; Stop-Npp
	$vertical = Compare-Crops $dwVertical['tabs'] $gdiVertical['tabs']
	Check 'vertical tabs (a rotated font): left to GDI, drawn as with GDI' ($vertical.Count -eq 0) "$($vertical.Count) pixels differ"

	# the Ctrl+Tab list, Antialiasing None: its text in two colours, also where it's painted again in part (the selection
	# moved: a buffered paint, its DC's origin shifted); GDI's ClearType would bring many (Ctrl held: keys sent to it)
	Start-Npp 'dw-ctrltab' 1 $false '' 'fontAntialiasing="4"'
	[void][UT]::SetForegroundWindow($script:main); Start-Sleep -Milliseconds 300
	[UT]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 100
	foreach ($i in 1..4) { [UT]::keybd_event(0x09, 0, 0, [UIntPtr]::Zero); [UT]::keybd_event(0x09, 0, 2, [UIntPtr]::Zero); Start-Sleep -Milliseconds 250 }
	Start-Sleep -Milliseconds 400
	$list = Get-Tops | Where-Object { [UT]::IsWindowVisible($_) -and ($_ -ne $script:main) -and ((Get-Cls $_) -eq '#32770') } | Select-Object -First 1
	$colours = -1
	if ($list) {
		$r = Get-Rect $list
		$bmp = [Drawing.Bitmap]::new([int]($r.Right - $r.Left), [int]($r.Bottom - $r.Top)); $g = [Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
		[void][UT]::PrintWindow($list, $hdc, 2); $g.ReleaseHdc($hdc); $g.Dispose(); $bmp.Save((Join-Path $root 'dw-ctrltab-list.png'))
		# the text's part (past the icons), within the border
		$textPart = $bmp.Clone([Drawing.Rectangle]::new([int]($bmp.Width * 0.1), 4, [int]($bmp.Width * 0.85), $bmp.Height - 8), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
		$colours = @(Get-Pixels $textPart | ForEach-Object { $_ -band 0xFFFFFF } | Sort-Object -Unique).Count
		$bmp.Dispose()
	}
	[UT]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300
	Stop-Npp
	if ($colours -lt 0) { $script:results.Add('INFO  the Ctrl+Tab list didn''t show (another window in front?): not checked') }
	else { Check 'the Ctrl+Tab list, Antialiasing None, the selection moved 4 times: its text without ClearType''s colours (DirectWrite all over)' ($colours -le 8) "$colours colours" }
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
