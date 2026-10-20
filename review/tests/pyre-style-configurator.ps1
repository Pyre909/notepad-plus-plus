# App-level test (review harness), Pyre909 builds only: the Style Configurator bugs fixed on 2026-10-19 (upstream ones).
# - A theme of the installation saved with Save & Close (a copy in the user's themes folder) keeps its changes when
#   selected again in the same session (the installation's file was loaded again, without them).
# - A dark mode switch selects the dark mode theme by its exact name: "Solarized", not "Solarized-light" (listed first).
# - An emptied font name is saved (it came back on the next start: upstream #13919), and so is a font name for a style
#   the theme gave none (defensive: Notepad++'s theme update adds the missing attribute from the model at load).
# - The user keywords typed are applied once the typing pauses, not on each key (each application restyles the views:
#   14.6 ms a key before, 2.7 ms after, with a 100,000-line C++ file; one restyle after the pause).
# Runs a copy of the build in a folder of its own with four of the installation's themes next to it (as installed), a
# settings folder of its own (the user's themes folder in it) and a C++ file of 100,000 lines.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [string] $ThemesDir = '', [double] $KeyMsMax = 8)
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
if (-not $ThemesDir) {
	$ThemesDir = @((Join-Path (Split-Path $Exe) 'themes'), (Join-Path (Split-Path (Split-Path $Exe)) 'installer\themes')) |
		Where-Object { Test-Path -LiteralPath (Join-Path $_ 'Monokai.xml') } | Select-Object -First 1
	if (-not $ThemesDir) { 'INFO  no themes folder (next to the exe or in the build tree): skipped'; '0 checks, 0 failed'; exit }
}
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class SC {
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr SendMessageStr(IntPtr h, uint m, IntPtr w, string l);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
}
'@
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $WM_CHAR = 0x0102; $BM_SETCHECK = 0x00F1
$CB_SETCURSEL = 0x014E; $CB_FINDSTRINGEXACT = 0x0158; $LB_SETCURSEL = 0x0186; $LB_FINDSTRINGEXACT = 0x01A2
$IDM_SETTING_PREFERENCE = 48011; $IDM_LANGSTYLE_CONFIG_DLG = 46001
$IDC_FONT_COMBO = 2202; $IDC_BOLD_CHECK = 2204; $IDC_USER_KEYWORDS_EDIT = 2222
$IDC_SAVECLOSE_BUTTON = 2301; $IDC_LANGUAGES_COMBO = 2304; $IDC_STYLES_LIST = 2305; $IDC_SWITCH2THEME_COMBO = 2307
$IDC_RADIO_DARKMODE_LIGHTMODE = 7131; $IDC_RADIO_DARKMODE_DARKMODE = 7132
$SCI_GETSTYLEAT = 2010; $SCI_STYLEGETBACK = 2482; $SCI_STYLEGETBOLD = 2483; $STYLE_DEFAULT = 32; $SCE_C_WORD = 5

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][SC]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][SC]::GetWindowText($h, $sb, 256); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][SC]::EnumWindows({ param($h, $l) $p = 0; [void][SC]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	$script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][SC]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids.ToArray()
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][SC]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 30000, [ref]$r); $r.ToInt64() }
# a top-level dialog of Notepad++ by its title, or its child page holding a control
function Find-Dialog([string] $title, [int] $controlId = 0) {
	for ($i = 0; $i -lt 50; $i++) {
		$dlg = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq $title -and [SC]::IsWindowVisible($_) } | Select-Object -First 1
		if ($dlg) {
			if (($controlId -eq 0) -or ([SC]::GetDlgItem($dlg, $controlId) -ne [IntPtr]::Zero)) { return $dlg }
			$page = Get-Kids $dlg | Where-Object { [SC]::GetDlgItem($_, $controlId) -ne [IntPtr]::Zero } | Select-Object -First 1
			if ($page) { return $page }
		}
		Start-Sleep -Milliseconds 100
	}
	[IntPtr]::Zero
}
# chooses an item of a combo or list box of the dialog by its text, as a click does
function Select-Text([IntPtr] $dlg, [int] $id, [string] $text, [switch] $List) {
	$box = [SC]::GetDlgItem($dlg, $id)
	$i = [SC]::SendMessageStr($box, $(if ($List) { $LB_FINDSTRINGEXACT } else { $CB_FINDSTRINGEXACT }), [IntPtr]-1, $text).ToInt64()
	if ($i -lt 0) { return $false }
	[void](Send $box $(if ($List) { $LB_SETCURSEL } else { $CB_SETCURSEL }) $i)
	[void](Send $dlg $WM_COMMAND ((1 -shl 16) -bor $id) $box.ToInt64())   # CBN_SELCHANGE / LBN_SELCHANGE
	Start-Sleep -Milliseconds 300
	$true
}
function Open-Styler { [void][SC]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_LANGSTYLE_CONFIG_DLG, [IntPtr]::Zero); Find-Dialog 'Style Configurator' }
function Save-Close([IntPtr] $dlg) { [void](Send $dlg $WM_COMMAND $IDC_SAVECLOSE_BUTTON ([SC]::GetDlgItem($dlg, $IDC_SAVECLOSE_BUTTON)).ToInt64()); Start-Sleep -Milliseconds 500 }
function Default-Style-Attr([string] $file, [string] $attr) {
	$m = [regex]::Match([IO.File]::ReadAllText($file), '<WidgetStyle name="Default Style"[^>]*>')
	if (-not $m.Success) { return $null }
	$a = [regex]::Match($m.Value, "\b$attr=""([^""]*)""")
	if ($a.Success) { $a.Groups[1].Value } else { $null }
}
function Bgr([string] $hex) { [Convert]::ToInt32($hex.Substring(4, 2) + $hex.Substring(2, 2) + $hex.Substring(0, 2), 16) }   # RRGGBB -> COLORREF

# the copy as installed: the exe, the models, four themes; the settings with a dark mode theme; a theme without fonts
$root = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-style-configurator-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$app = Join-Path $root 'app'; $settings = Join-Path $root 'settings'
New-Item -ItemType Directory -Force (Join-Path $app 'themes'), (Join-Path $settings 'themes') | Out-Null
Copy-Item $Exe $app
foreach ($model in 'langs.model.xml', 'stylers.model.xml') {
	$src = @((Join-Path (Split-Path $Exe) $model), (Join-Path (Split-Path (Split-Path $Exe)) "src\$model")) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
	Copy-Item $src $app
}
foreach ($theme in 'Monokai', 'Zenburn', 'Solarized', 'Solarized-light') { Copy-Item (Join-Path $ThemesDir "$theme.xml") (Join-Path $app 'themes') }
[IO.File]::WriteAllText((Join-Path $settings 'config.xml'), @'
<?xml version="1.0" encoding="UTF-8" ?>
<NotepadPlus>
    <GUIConfigs>
        <GUIConfig name="DarkMode" enable="no" darkThemeName="Solarized.xml" />
    </GUIConfigs>
</NotepadPlus>
'@)
$noFont = Join-Path $settings 'themes\NoFont.xml'
[IO.File]::WriteAllText($noFont, @'
<?xml version="1.0" encoding="UTF-8" ?>
<NotepadPlus>
    <LexerStyles />
    <GlobalStyles>
        <WidgetStyle name="Default Style" styleID="32" fgColor="000000" bgColor="FFFFFF" fontStyle="0" fontSize="10" />
    </GlobalStyles>
</NotepadPlus>
'@)
$cpp = Join-Path $root 'words.cpp'; [IO.File]::WriteAllLines($cpp, [string[]](1..100000 | ForEach-Object { "int fooword$_ = fooword; // line $_" }))
$appExe = Join-Path $app (Split-Path $Exe -Leaf)

$proc = Start-Process $appExe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $cpp -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 1000
	$view = Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [SC]::IsWindowVisible($_) -and ([SC]::GetParent($_) -eq $script:main) } | Select-Object -First 1

	# an emptied font name, saved (Default (stylers.xml): the settings' stylers.xml)
	$dlg = Open-Styler
	[void](Select-Text $dlg $IDC_LANGUAGES_COMBO 'Global Styles'); [void](Select-Text $dlg $IDC_STYLES_LIST 'Default Style' -List)
	$fontBox = [SC]::GetDlgItem($dlg, $IDC_FONT_COMBO)
	[void](Send $fontBox $CB_SETCURSEL 0); [void](Send $dlg $WM_COMMAND ((1 -shl 16) -bor $IDC_FONT_COMBO) $fontBox.ToInt64()); Start-Sleep -Milliseconds 300
	Save-Close $dlg
	$font = Default-Style-Attr (Join-Path $settings 'stylers.xml') 'fontName'
	Check 'emptied font name of the Default Style saved in stylers.xml (#13919)' ($font -eq '') "fontName=""$font"""

	# a font name for a style the theme gave none
	$dlg = Open-Styler
	Check '  theme NoFont selected' (Select-Text $dlg $IDC_SWITCH2THEME_COMBO 'NoFont')
	[void](Select-Text $dlg $IDC_LANGUAGES_COMBO 'Global Styles'); [void](Select-Text $dlg $IDC_STYLES_LIST 'Default Style' -List)
	[void](Select-Text $dlg $IDC_FONT_COMBO 'Consolas')
	Save-Close $dlg
	$font = Default-Style-Attr $noFont 'fontName'
	$shown = if ($null -eq $font) { '(no attribute)' } else { '"' + $font + '"' }
	Check 'font name saved where the theme had none' ($font -eq 'Consolas') "fontName $shown"

	# an installation's theme saved as the user's copy, then selected again in the same session
	$dlg = Open-Styler
	[void](Select-Text $dlg $IDC_SWITCH2THEME_COMBO 'Monokai')
	[void](Select-Text $dlg $IDC_LANGUAGES_COMBO 'Global Styles'); [void](Select-Text $dlg $IDC_STYLES_LIST 'Default Style' -List)
	$bold = [SC]::GetDlgItem($dlg, $IDC_BOLD_CHECK)
	[void](Send $bold $BM_SETCHECK 1); [void](Send $dlg $WM_COMMAND $IDC_BOLD_CHECK $bold.ToInt64()); Start-Sleep -Milliseconds 300
	Save-Close $dlg
	$copy = Join-Path $settings 'themes\Monokai.xml'
	Check 'Monokai saved as the user''s copy, Default Style bold' ((Test-Path $copy) -and ((Default-Style-Attr $copy 'fontStyle') -eq '1') -and ((Send $view $SCI_STYLEGETBOLD $STYLE_DEFAULT) -eq 1))
	$dlg = Open-Styler
	[void](Select-Text $dlg $IDC_SWITCH2THEME_COMBO 'Zenburn')
	[void](Select-Text $dlg $IDC_SWITCH2THEME_COMBO 'Monokai')
	Check 'Monokai selected again: the saved copy (bold), not the installation''s' ((Send $view $SCI_STYLEGETBOLD $STYLE_DEFAULT) -eq 1) "bold $(Send $view $SCI_STYLEGETBOLD $STYLE_DEFAULT)"

	# user keywords typed: applied once the typing pauses, not on each key
	[void](Select-Text $dlg $IDC_LANGUAGES_COMBO 'C++'); [void](Select-Text $dlg $IDC_STYLES_LIST 'INSTRUCTION WORD' -List)
	$keywords = [SC]::GetDlgItem($dlg, $IDC_USER_KEYWORDS_EDIT)
	$text = 'fooword'
	$sw = [Diagnostics.Stopwatch]::StartNew()
	foreach ($c in $text.ToCharArray()) { [void](Send $keywords $WM_CHAR ([int]$c)) }
	$perKey = [math]::Round($sw.Elapsed.TotalMilliseconds / $text.Length, 1)
	Start-Sleep -Milliseconds 800
	Check "user keywords: typing them costs under $KeyMsMax ms a key (the restyle waits for a pause)" ($perKey -lt $KeyMsMax) "$perKey ms a key, a 100,000-line C++ file open"
	$style = Send $view $SCI_GETSTYLEAT 15   # "fooword" after "int fooword1 = "
	Check '  applied once the typing paused: "fooword" is an instruction word' ($style -eq $SCE_C_WORD) "style $style"
	[void](Send $dlg $WM_COMMAND 2 0); Start-Sleep -Milliseconds 300   # IDCANCEL: the keywords discarded

	# a dark mode switch with the Style Configurator created: its dark mode theme, Solarized (not Solarized-light)
	[void][SC]::PostMessage($script:main, $WM_COMMAND, [IntPtr]$IDM_SETTING_PREFERENCE, [IntPtr]::Zero)
	$darkPage = Find-Dialog 'Preferences' $IDC_RADIO_DARKMODE_DARKMODE
	foreach ($pair in @(@($IDC_RADIO_DARKMODE_DARKMODE, $IDC_RADIO_DARKMODE_LIGHTMODE), @($IDC_RADIO_DARKMODE_LIGHTMODE, $IDC_RADIO_DARKMODE_DARKMODE))) {
		[void](Send ([SC]::GetDlgItem($darkPage, $pair[1])) $BM_SETCHECK 0); [void](Send ([SC]::GetDlgItem($darkPage, $pair[0])) $BM_SETCHECK 1)
		[void](Send $darkPage $WM_COMMAND $pair[0] ([SC]::GetDlgItem($darkPage, $pair[0])).ToInt64()); Start-Sleep -Milliseconds 1000
		if ($pair[0] -eq $IDC_RADIO_DARKMODE_DARKMODE) {
			$back = Send $view $SCI_STYLEGETBACK $STYLE_DEFAULT
			Check 'dark mode: its theme Solarized, not Solarized-light' ($back -eq (Bgr '002B36')) ('Default Style background {0:X6}, Solarized {1:X6}, Solarized-light {2:X6} (BGR)' -f $back, (Bgr '002B36'), (Bgr 'FDF6E3'))
		}
	}
}
finally {
	if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
	$script:results
	"folder: $root"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
