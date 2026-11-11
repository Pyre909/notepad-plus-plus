# App-level test (review harness), Pyre909 builds only: the light tab bar painted in the editor's colours (2026-11-10,
# TabBarPlus::setEditorColours): in light mode with a light editor background, the strip a shade darker than the text's
# background (6% of the text's colour mixed in), the active tab on the text's background under its top bar with a border
# (30%), the inactive tabs a shade darker than the strip (11%) with a lighter border (22%), a gap between tabs. Another light
# theme: its own shades; Global override's background enabled: the tabs in it, as the editor. A dark editor theme in light
# mode: the tab bar as upstream's (the light mode's buttons are drawn for a light background). Pixels of the window (PrintWindow) at the tabs' rectangles (TCM_GETITEMRECT).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace ET -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc proc, IntPtr l);
[DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
[DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, UIntPtr size, uint type, uint protect);
[DllImport("kernel32.dll")] public static extern bool VirtualFreeEx(IntPtr p, IntPtr a, UIntPtr size, uint type);
[DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] b, UIntPtr size, out UIntPtr read);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
public static System.Collections.Generic.List<IntPtr> Children(IntPtr parent, string cls) {
	var found = new System.Collections.Generic.List<IntPtr>();
	EnumChildWindows(parent, (h, l) => { var sb = new System.Text.StringBuilder(64); GetClassName(h, sb, 64); if (sb.ToString() == cls && IsWindowVisible(h)) found.Add(h); return true; }, IntPtr.Zero);
	return found;
}
'@
[void][ET.U]::SetThreadDpiAwarenessContext([IntPtr](-4)) # per-monitor v2: rectangles in the pixels PrintWindow draws
$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $m, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][ET.U]::SendMessageTimeout($h, $m, [IntPtr]$w, [IntPtr]$l, 2, 10000, [ref]$r); $r.ToInt64() }

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-editor-tabs-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $root | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
$first = Join-Path $root 'first.txt'; [IO.File]::WriteAllText($first, "first`r`n", $utf8)
$second = Join-Path $root 'second.txt'; [IO.File]::WriteAllText($second, "second`r`n", $utf8)
$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
function Theme([string] $text, [string] $background) {
	$t = [regex]::Replace($model, '(<WidgetStyle name="Default Style" styleID="32" fgColor=")[0-9A-Fa-f]{6}(" bgColor=")[0-9A-Fa-f]{6}"', "`${1}$text`${2}$background`"")
	[regex]::Replace($t, '(<WidgetStyle name="Active tab focused indicator" styleID="0" fgColor=")[0-9A-Fa-f]{6}"', "`${1}C2570C`"")
}
# the mix of the text's colour into the background, as TabBarPlus's mixColour; colours "RRGGBB"
function Mix([string] $background, [string] $text, [int] $percent) {
	$b = [Convert]::ToInt32($background, 16); $t = [Convert]::ToInt32($text, 16)
	(16, 8, 0 | ForEach-Object { '{0:X2}' -f [int][Math]::Floor(((($b -shr $_) -band 0xFF) * (100 - $percent) + (($t -shr $_) -band 0xFF) * $percent + 50) / 100) }) -join ''
}
function Hex([Drawing.Color] $c) { '{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B }

function Start-Npp([string] $name, [string] $theme, [string] $config = '') {
	$settings = Join-Path $root $name; New-Item -ItemType Directory -Force $settings | Out-Null
	[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $theme, $utf8)
	if ($config) { [IO.File]::WriteAllText((Join-Path $settings 'config.xml'), $config, $utf8) }
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', "`"$first`"", "`"$second`"" -PassThru
	for ($i = 0; $i -lt 100 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 100; $p.Refresh() }
	Start-Sleep -Milliseconds 1500
	$script:main = $p.MainWindowHandle
	$script:tab = @([ET.U]::Children($script:main, 'SysTabControl32') | Where-Object { (Send $_ 0x1304) -eq 2 })[0] # TCM_GETITEMCOUNT
	$script:proc = [ET.U]::OpenProcess(0x0438, $false, $p.Id); $script:mem = [ET.U]::VirtualAllocEx($script:proc, [IntPtr]::Zero, [UIntPtr]64, 0x3000, 4)
	$p
}
function Stop-Npp($p) {
	[void][ET.U]::VirtualFreeEx($script:proc, $script:mem, [UIntPtr]::Zero, 0x8000); [void][ET.U]::CloseHandle($script:proc)
	[void][ET.U]::PostMessage($script:main, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force }
}
function Item-Rect([int] $index) { # TCM_GETITEMRECT, read through memory in the process
	[void](Send $script:tab 0x130A $index ([Int64]$script:mem))
	$b = [byte[]]::new(16); $r = [UIntPtr]::Zero; [void][ET.U]::ReadProcessMemory($script:proc, $script:mem, $b, [UIntPtr]16, [ref]$r)
	@{ Left = [BitConverter]::ToInt32($b, 0); Top = [BitConverter]::ToInt32($b, 4); Right = [BitConverter]::ToInt32($b, 8); Bottom = [BitConverter]::ToInt32($b, 12) }
}
# the tab bar's pixels: a function of (x, y) in the tab control's client coordinates
function Get-TabPixels {
	$rm = [ET.U+RECT]::new(); [void][ET.U]::GetWindowRect($script:main, [ref]$rm); $pt = [ET.U+POINT]::new(); [void][ET.U]::ClientToScreen($script:tab, [ref]$pt)
	$bmp = [Drawing.Bitmap]::new($rm.Right - $rm.Left, $rm.Bottom - $rm.Top); $g = [Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc(); [void][ET.U]::PrintWindow($script:main, $hdc, 2); $g.ReleaseHdc($hdc); $g.Dispose()
	@{ Bitmap = $bmp; X = $pt.X - $rm.Left; Y = $pt.Y - $rm.Top }
}
function Px($cap, [int] $x, [int] $y) { Hex $cap.Bitmap.GetPixel($x + $cap.X, $y + $cap.Y) }
# the most frequent colour of an area (a tab's background, around its icon, text and buttons)
function Mode($cap, [int] $x1, [int] $x2, [int] $y1, [int] $y2) {
	$counts = @{}
	for ($y = $y1; $y -lt $y2; $y++) { for ($x = $x1; $x -lt $x2; $x++) { $c = Px $cap $x $y; $counts[$c] = 1 + [int]$counts[$c] } }
	($counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
}
# the colours read: the strip (after the last tab), the gap between the tabs, the active and inactive tabs' backgrounds,
# the active tab's left edge (a column each of its first pixels), its top bar; the first pixel of the icon from the left
function Read-Tabs {
	$selected = Send $script:tab 0x130B # TCM_GETCURSEL
	$active = Item-Rect $selected; $inactive = Item-Rect (1 - $selected)
	$left = if ($selected -eq 0) { $active } else { $inactive }
	$client = [ET.U+RECT]::new(); [void][ET.U]::GetClientRect($script:tab, [ref]$client)
	$cap = Get-TabPixels
	$middle = [int](($active.Top + $active.Bottom) / 2)
	$read = [ordered]@{
		strip = Px $cap ($client.Right - 4) $middle
		gap = Px $cap ($left.Right - 1) $middle
		active = Mode $cap ($active.Left + 4) ($active.Right - 4) ($active.Top + 8) ($active.Bottom - 1)
		inactive = Mode $cap ($inactive.Left + 4) ($inactive.Right - 4) ($inactive.Top + 8) ($inactive.Bottom - 1)
		border = @(for ($x = $active.Left; $x -lt $active.Left + 4; $x++) { Mode $cap $x ($x + 1) ($active.Top + 8) ($active.Bottom - 1) })
		topBar = Px $cap ([int](($active.Left + $active.Right) / 2)) ($active.Top + 1)
	}
	$cap.Bitmap.Dispose(); $read
}
function Near([string] $a, [string] $b) { # within 2 of each channel
	$x = [Convert]::ToInt32($a, 16); $y = [Convert]::ToInt32($b, 16)
	@(16, 8, 0 | Where-Object { [Math]::Abs((($x -shr $_) -band 0xFF) - (($y -shr $_) -band 0xFF)) -gt 2 }).Count -eq 0
}
function Show($read) { ($read.Keys | ForEach-Object { "$_ $($read[$_] -join '/')" }) -join ', ' }

try {
	foreach ($case in @(@('warm', '191E28', 'FCFCF9'), @('blue', '102040', 'EEF5FF'))) {
		$p = Start-Npp $case[0] (Theme $case[1] $case[2])
		$read = Read-Tabs
		$want = @{ strip = (Mix $case[2] $case[1] 6); inactive = (Mix $case[2] $case[1] 11); border = (Mix $case[2] $case[1] 30) }
		Check "light mode, Default Style $($case[2]) on $($case[1]): the strip $($want.strip), the gap between tabs the strip's, the active tab $($case[2]), the inactive $($want.inactive)" ((Near $read.strip $want.strip) -and (Near $read.gap $want.strip) -and (Near $read.active $case[2]) -and (Near $read.inactive $want.inactive)) (Show $read)
		Check "  the active tab's border $($want.border), its top bar the theme's (C2570C)" ((@($read.border | Where-Object { Near $_ $want.border }).Count -ge 1) -and (Near $read.topBar 'C2570C')) (Show $read)
		Stop-Npp $p
	}
	# Global override's background enabled (as the editor draws it): the tabs in it
	$override = [regex]::Replace((Theme '191E28' 'FCFCF9'), '(<WidgetStyle name="Global override" styleID="0" fgColor=")[0-9A-Fa-f]{6}(" bgColor=")[0-9A-Fa-f]{6}"', "`${1}FFFF80`${2}FFF4E0`"")
	$p = Start-Npp 'override' $override '<?xml version="1.0" encoding="UTF-8" ?><NotepadPlus><GUIConfigs><GUIConfig name="globalOverride" fg="no" bg="yes" font="no" fontSize="no" bold="no" italic="no" underline="no" /></GUIConfigs></NotepadPlus>'
	$read = Read-Tabs
	Check 'Global override''s background enabled (FFF4E0): the active tab in it, the strip from it' ((Near $read.active 'FFF4E0') -and (Near $read.strip (Mix 'FFF4E0' '191E28' 6))) (Show $read)
	Stop-Npp $p
	# a dark editor theme in light mode: as upstream's (the editor's background nowhere in the tab bar)
	$p = Start-Npp 'dark-editor' (Theme 'DCDCDC' '1E1E1E')
	$read = Read-Tabs
	Check 'a dark editor theme in light mode: the tab bar as upstream''s (neither the editor''s background nor its strip)' ((-not (Near $read.active '1E1E1E')) -and (-not (Near $read.strip (Mix '1E1E1E' 'DCDCDC' 6)))) (Show $read)
	Stop-Npp $p
}
finally {
	Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -like '*REVIEW-TEST*' } | Stop-Process -Force
	$script:results
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
