# App-level test (review harness), Pyre909 builds only: the font of every theme, the Style Configurator's "For every theme"
# row (font, size, bold, italic, underline forced for all styles, in config.xml rather than in the theme's Global override
# style). It's forced whatever the theme, switching themes keeps it, Cancel restores it, the Global override entry keeps
# its colours only; a config.xml without it (another Notepad++'s) takes the theme's Global override values once.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe)
$ErrorActionPreference = 'Stop'
# a Pyre909 build names itself in its About box (PYRE_BUILD_TAG in AboutDlg.cpp)
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
# Monokai, the theme switched to: next to an installed exe, else in the sources of a build's tree
$monokai = @((Join-Path (Split-Path $Exe) 'themes\Monokai.xml'), (Join-Path (Split-Path (Split-Path $Exe)) 'installer\themes\Monokai.xml')) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $monokai) { 'INFO  no Monokai.xml theme found: skipped'; '0 checks, 0 failed'; exit }
Add-Type -Namespace FT -Name U -MemberDefinition @'
public delegate bool EnumProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, System.Text.StringBuilder l);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
[DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr addr, UIntPtr size, uint type, uint protect);
[DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr h, IntPtr addr, UIntPtr size, uint type);
[DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, UIntPtr size, out UIntPtr read);
[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
// SCI_STYLEGETFONT writes the name into a buffer of the Scintilla's process: one is allocated there, then read back
public static string StyleFont(IntPtr view, uint pid, int style) {
  IntPtr proc = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid); // PROCESS_VM_OPERATION | VM_READ | VM_WRITE
  if (proc == IntPtr.Zero) return "?";
  IntPtr mem = VirtualAllocEx(proc, IntPtr.Zero, (UIntPtr)256, 0x3000, 0x04); // MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE
  string name = "?";
  if (mem != IntPtr.Zero) {
    IntPtr r;
    SendMessageTimeout(view, 2486, (IntPtr)style, mem, 2, 3000, out r); // SCI_STYLEGETFONT
    byte[] buf = new byte[256]; UIntPtr n;
    if (ReadProcessMemory(proc, mem, buf, (UIntPtr)256, out n)) { int len = System.Array.IndexOf(buf, (byte)0); name = System.Text.Encoding.UTF8.GetString(buf, 0, len < 0 ? 256 : len); }
    VirtualFreeEx(proc, mem, UIntPtr.Zero, 0x8000); // MEM_RELEASE
  }
  CloseHandle(proc);
  return name;
}
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $WM_GETTEXT = 0x000D; $CB_SETCURSEL = 0x014E; $CB_FINDSTRINGEXACT = 0x0158
$LB_SETCURSEL = 0x0186; $LB_FINDSTRINGEXACT = 0x01A2; $IDCANCEL = 2; $IDM_LANGSTYLE_CONFIG_DLG = 46001
$STYLE_DEFAULT = 32; $SCE_C_WORD = 5 # C++ keywords: bold in the default theme, not in Monokai
$IDC_FONT_COMBO = 2202; $IDC_GLOBAL_FG_CHECK = 2226; $IDC_GLOBAL_FONT_CHECK = 2228; $IDC_STYLES_LIST = 2305; $IDC_SWITCH2THEME_COMBO = 2307
$IDC_EVERYTHEME_FONT_COMBO = 2281; $IDC_EVERYTHEME_SIZE_COMBO = 2283; $IDC_EVERYTHEME_BOLD_COMBO = 2285
$IDC_EVERYTHEME_ITALIC_COMBO = 2287; $IDC_EVERYTHEME_UNDERLINE_COMBO = 2289; $IDC_EVERYTHEME_NOTE_STATIC = 2290

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][FT.U]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][FT.U]::GetClassName($h, $sb, 64); $sb.ToString() }
# WM_GETTEXT is marshalled across processes (GetWindowText isn't, for controls)
function Get-Text([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][FT.U]::SendMessage($h, $WM_GETTEXT, [IntPtr]256, $sb); $sb.ToString() }
function Get-Kids([IntPtr] $p) { $script:kids = [Collections.Generic.List[IntPtr]]::new(); [void][FT.U]::EnumChildWindows($p, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero); $script:kids.ToArray() }
function Get-Tops([uint32] $procId) { $script:tops = [Collections.Generic.List[IntPtr]]::new(); [void][FT.U]::EnumWindows({ param($h, $l) $p = 0; [void][FT.U]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $procId) { $script:tops.Add($h) }; $true }, [IntPtr]::Zero); $script:tops.ToArray() }

function Start-Npp([string] $settings, [string[]] $files = @()) {
	$p = Start-Process $Exe -ArgumentList (@('-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST') + $files) -PassThru
	for ($i = 0; $i -lt 100; $i++) { $p.Refresh(); if ($p.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	Start-Sleep -Milliseconds 800
	$p
}
# closes Notepad++, answering No to a "Save file?"; the messages seen
function Stop-Npp($p) {
	$boxes = @()
	if (-not $p.HasExited) {
		[void][FT.U]::PostMessage($p.MainWindowHandle, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
		for ($i = 0; $i -lt 60 -and -not $p.HasExited; $i++) {
			Start-Sleep -Milliseconds 250
			foreach ($b in @(Get-Tops ([uint32]$p.Id) | Where-Object { (Get-Cls $_) -eq '#32770' -and [FT.U]::IsWindowVisible($_) -and ((Get-Text $_) -ne 'Style Configurator') })) {
				$boxes += Get-Text $b
				$no = [FT.U]::GetDlgItem($b, 7); if ($no -ne [IntPtr]::Zero) { [void][FT.U]::PostMessage($b, $WM_COMMAND, [IntPtr]7, $no) } else { [void][FT.U]::PostMessage($b, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
			}
		}
		if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force }
	}
	$boxes
}
function Get-View($p) { Get-Kids $p.MainWindowHandle | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [FT.U]::IsWindowVisible($_) -and [FT.U]::GetParent($_) -eq $p.MainWindowHandle } | Select-Object -First 1 }
# the font, size and bold of the Default Style and of the C++ keywords, and the Default Style's background
function Get-Styles($p, [IntPtr] $view) {
	[pscustomobject]@{
		Font = [FT.U]::StyleFont($view, [uint32]$p.Id, $STYLE_DEFAULT); Size = Send $view 2485 $STYLE_DEFAULT
		WordFont = [FT.U]::StyleFont($view, [uint32]$p.Id, $SCE_C_WORD); WordSize = Send $view 2485 $SCE_C_WORD; WordBold = Send $view 2483 $SCE_C_WORD
		Back = Send $view 2482 $STYLE_DEFAULT
	}
}
function Show-Styles($s) { "Default Style {0} {1}, keywords {2} {3} bold {4}, background {5:X6}" -f $s.Font, $s.Size, $s.WordFont, $s.WordSize, $s.WordBold, $s.Back }
function Get-GlobalOverride([string] $config) { if ($config -match '<GUIConfig name="globalOverride"[^>]*/>') { $Matches[0] } else { '(none)' } }

$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-font-every-theme-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
try {
	# --- the font of every theme in config.xml: Consolas 13, never bold
	$settings = Join-Path $root 'main'; New-Item -ItemType Directory -Force (Join-Path $settings 'themes') | Out-Null
	[void](Stop-Npp (Start-Npp $settings)) # writes config.xml and stylers.xml
	$configPath = Join-Path $settings 'config.xml'
	$config = [IO.File]::ReadAllText($configPath) -replace '<GUIConfig name="globalOverride"[^>]*/>', '<GUIConfig name="globalOverride" fg="no" bg="no" font="yes" fontSize="yes" bold="yes" italic="no" underline="no" forcedFontName="Consolas" forcedFontSize="13" forcedFontStyle="0" />'
	[IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))
	Copy-Item -LiteralPath $monokai (Join-Path $settings 'themes')
	$file = Join-Path $settings 'test.cpp'; [IO.File]::WriteAllLines($file, [string[]]@('int main()', '{', '	return 0;', '}'))

	$proc = Start-Npp $settings @($file)
	$view = Get-View $proc
	$s = Get-Styles $proc $view
	Check 'start: every style in Consolas 13, the keywords not bold' (($s.Font -eq 'Consolas') -and ($s.Size -eq 13) -and ($s.WordFont -eq 'Consolas') -and ($s.WordSize -eq 13) -and ($s.WordBold -eq 0)) (Show-Styles $s)

	[void](Send $proc.MainWindowHandle $WM_COMMAND $IDM_LANGSTYLE_CONFIG_DLG)
	$dlg = [IntPtr]::Zero
	for ($i = 0; $i -lt 40 -and $dlg -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 250; $dlg = Get-Tops ([uint32]$proc.Id) | Where-Object { [FT.U]::IsWindowVisible($_) -and (Get-Text $_) -eq 'Style Configurator' } | Select-Object -First 1 }
	Check 'Style Configurator opened' ($dlg -ne $null -and $dlg -ne [IntPtr]::Zero)
	$combo = @{}; foreach ($id in $IDC_EVERYTHEME_FONT_COMBO, $IDC_EVERYTHEME_SIZE_COMBO, $IDC_EVERYTHEME_BOLD_COMBO, $IDC_EVERYTHEME_ITALIC_COMBO, $IDC_EVERYTHEME_UNDERLINE_COMBO) { $combo[$id] = [FT.U]::GetDlgItem($dlg, $id) }
	function Get-Row { ($IDC_EVERYTHEME_FONT_COMBO, $IDC_EVERYTHEME_SIZE_COMBO, $IDC_EVERYTHEME_BOLD_COMBO, $IDC_EVERYTHEME_ITALIC_COMBO, $IDC_EVERYTHEME_UNDERLINE_COMBO | ForEach-Object { Get-Text $combo[$_] }) -join ' / ' }
	function Select-Item([int] $id, [int] $index) {
		[void](Send $combo[$id] $CB_SETCURSEL $index)
		[void](Send $dlg $WM_COMMAND ((1 -shl 16) -bor $id) $combo[$id].ToInt64()) # CBN_SELCHANGE
		Start-Sleep -Milliseconds 300
	}
	$row = Get-Row
	Check 'the row shows config.xml: Consolas, 13, bold Never, italic and underline the theme''s' ($row -eq 'Consolas / 13 / Never / (Theme) / (Theme)') $row

	Select-Item $IDC_EVERYTHEME_BOLD_COMBO 0; $s = Get-Styles $proc $view
	Check 'Bold (Theme): the keywords bold, as the theme has them' ($s.WordBold -eq 1) (Show-Styles $s)
	Select-Item $IDC_EVERYTHEME_BOLD_COMBO 2; $s = Get-Styles $proc $view
	Check 'Bold Never again: the keywords not bold' ($s.WordBold -eq 0) (Show-Styles $s)

	$themeCombo = [FT.U]::GetDlgItem($dlg, $IDC_SWITCH2THEME_COMBO)
	$monokaiIndex = [FT.U]::SendMessage($themeCombo, $CB_FINDSTRINGEXACT, [IntPtr](-1), 'Monokai').ToInt64()
	[void](Send $themeCombo $CB_SETCURSEL $monokaiIndex)
	[void](Send $dlg $WM_COMMAND ((1 -shl 16) -bor $IDC_SWITCH2THEME_COMBO) $themeCombo.ToInt64())
	Start-Sleep -Milliseconds 500
	$s = Get-Styles $proc $view
	Check 'switched to Monokai: its background, the font of every theme kept (its own is DejaVu Sans Mono 10)' (($s.Back -eq 0x222827) -and ($s.Font -eq 'Consolas') -and ($s.Size -eq 13) -and ($s.WordFont -eq 'Consolas') -and ($s.WordBold -eq 0)) (Show-Styles $s)
	$row = Get-Row
	Check '  the row unchanged' ($row -eq 'Consolas / 13 / Never / (Theme) / (Theme)') $row

	# the Global override entry: its colours, a note in place of its font controls
	$list = [FT.U]::GetDlgItem($dlg, $IDC_STYLES_LIST)
	function Select-Style([string] $name) {
		$index = [FT.U]::SendMessage($list, $LB_FINDSTRINGEXACT, [IntPtr](-1), $name).ToInt64()
		[void](Send $list $LB_SETCURSEL $index)
		[void](Send $dlg $WM_COMMAND ((1 -shl 16) -bor $IDC_STYLES_LIST) $list.ToInt64()) # LBN_SELCHANGE
		Start-Sleep -Milliseconds 300
	}
	function Test-Shown([int] $id) { [FT.U]::IsWindowVisible([FT.U]::GetDlgItem($dlg, $id)) }
	Select-Style 'Global override'
	$shown = "note {0}, font combo {1}, font check box {2}, foreground check box {3}" -f (Test-Shown $IDC_EVERYTHEME_NOTE_STATIC), (Test-Shown $IDC_FONT_COMBO), (Test-Shown $IDC_GLOBAL_FONT_CHECK), (Test-Shown $IDC_GLOBAL_FG_CHECK)
	Check 'Global override: the note and the colour check boxes, no font controls' ((Test-Shown $IDC_EVERYTHEME_NOTE_STATIC) -and -not (Test-Shown $IDC_FONT_COMBO) -and -not (Test-Shown $IDC_GLOBAL_FONT_CHECK) -and (Test-Shown $IDC_GLOBAL_FG_CHECK)) $shown
	Select-Style 'Default Style'
	Check 'Default Style: its font controls back, no note' ((Test-Shown $IDC_FONT_COMBO) -and -not (Test-Shown $IDC_EVERYTHEME_NOTE_STATIC))

	# Notepad++ draws a font that isn't installed in Courier New (ScintillaEditView::setSpecialStyle)
	Select-Item $IDC_EVERYTHEME_FONT_COMBO 0; $s = Get-Styles $proc $view
	Check 'font (Theme): Monokai''s own font, DejaVu Sans Mono (Courier New if not installed), size still 13' (($s.Font -in 'DejaVu Sans Mono', 'Courier New') -and ($s.Size -eq 13)) (Show-Styles $s)

	[void](Send $dlg $WM_COMMAND $IDCANCEL); Start-Sleep -Milliseconds 500
	$s = Get-Styles $proc $view
	Check 'Cancel: the default theme and Consolas 13 back' (($s.Back -eq 0xFFFFFF) -and ($s.Font -eq 'Consolas') -and ($s.Size -eq 13) -and ($s.WordBold -eq 0)) (Show-Styles $s)
	$row = Get-Row
	Check '  the row back too' ($row -eq 'Consolas / 13 / Never / (Theme) / (Theme)') $row

	$boxes = Stop-Npp $proc
	Check 'exit: no message' ($boxes.Count -eq 0) ($boxes -join '; ')
	$go = Get-GlobalOverride ([IO.File]::ReadAllText($configPath))
	Check 'saved in config.xml' ($go -match 'font="yes"' -and $go -match 'fontSize="yes"' -and $go -match 'bold="yes"' -and $go -match 'italic="no"' -and $go -match 'forcedFontName="Consolas"' -and $go -match 'forcedFontSize="13"' -and $go -match 'forcedFontStyle="0"') $go

	# --- a config.xml without it (another Notepad++'s): the theme's Global override values, once
	$settings = Join-Path $root 'migration'; New-Item -ItemType Directory -Force $settings | Out-Null
	[void](Stop-Npp (Start-Npp $settings))
	$configPath = Join-Path $settings 'config.xml'
	$config = [IO.File]::ReadAllText($configPath) -replace '<GUIConfig name="globalOverride"[^>]*/>', '<GUIConfig name="globalOverride" fg="no" bg="no" font="yes" fontSize="yes" bold="no" italic="no" underline="no" />'
	[IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))
	$stylersPath = Join-Path $settings 'stylers.xml'
	$stylers = [IO.File]::ReadAllText($stylersPath)
	$stylers = [regex]::Replace($stylers, '<WidgetStyle name="Global override"[^>]*/>', { param($m) $m.Value -replace 'fontName="[^"]*"', 'fontName="Lucida Console"' -replace 'fontSize="[^"]*"', 'fontSize="12"' })
	[IO.File]::WriteAllText($stylersPath, $stylers, [Text.UTF8Encoding]::new($false))
	$proc = Start-Npp $settings
	$s = Get-Styles $proc (Get-View $proc)
	Check 'config.xml of another Notepad++: the theme''s Global override font, Lucida Console 12' (($s.Font -eq 'Lucida Console') -and ($s.Size -eq 12)) (Show-Styles $s)
	[void](Stop-Npp $proc)
	$go = Get-GlobalOverride ([IO.File]::ReadAllText($configPath))
	Check '  saved in config.xml since' ($go -match 'forcedFontName="Lucida Console"' -and $go -match 'forcedFontSize="12"') $go
}
finally {
	foreach ($p in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $p.Id -Force }
	$script:results
	"settings folders: $root"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
