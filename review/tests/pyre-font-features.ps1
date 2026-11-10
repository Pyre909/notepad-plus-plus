# App-level test (review harness), Pyre909 builds only: Preferences > Fonts, the fonts' OpenType features (config.xml
# fontFeatures, pyre's SCI_SETFONTFEATURES). Cascadia Code (Windows 11) as Default Style: the page lists its features
# (its stylistic sets, the italic's ss01 too, zero, calt...), checked as drawn (calt on by default); a list typed in the
# page's text applies once the typing pauses to both views of a document and the Document Map, checks the list as
# Scintilla reads it ("-zero=1" on, "zero=00" off), and draws differently ("zero": a slashed zero; "-calt": no
# ligatures); what isn't a feature is ignored; a feature with a value unchecked and checked again gets its value back;
# cleared, the text is drawn as before. The bold weight (config.xml boldWeight): SemiBold makes the bold styles 600 in
# both views, Medium 500 (DirectWrite draws Cascadia Code heavier at 500), Bold 700 again; with GDI (its "Cascadia Code"
# Regular and Bold), Medium is Bold. The fallback fonts (config.xml fontFallback): a serif
# CJK font listed draws the CJK line (Cascadia Code has none) instead of Windows' choice; a font DirectWrite doesn't know
# is left out; a GDI name ("Cascadia Code SemiBold") is given as its family. Saved in config.xml and read back.
# Without Cascadia Code, the drawing and list checks are skipped.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [string] $Font = 'Cascadia Code')
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class FF {
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
	[DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] static extern IntPtr SendMessageSb(IntPtr h, uint m, IntPtr w, StringBuilder l);
	// a control's text, of another process too (WM_GETTEXT, which GetWindowText doesn't send there)
	public static string GetText(IntPtr h) { var sb = new StringBuilder(1024); SendMessageSb(h, 0x000D, new IntPtr(1024), sb); return sb.ToString(); }
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
	[DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	[DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
	[DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
	[DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
	[DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
	[DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
	[DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
	[DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
	[DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
	[DllImport("gdi32.dll")] static extern int GetDIBits(IntPtr dc, IntPtr bmp, uint start, uint lines, int[] bits, ref BITMAPINFOHEADER bi, uint usage);
	struct RECT { public int L, T, R, B; }
	[StructLayout(LayoutKind.Sequential)] public struct BITMAPINFOHEADER {
		public int biSize, biWidth, biHeight; public short biPlanes, biBitCount; public int biCompression, biSizeImage, biXPelsPerMeter, biYPelsPerMeter, biClrUsed, biClrImportant; }
	public static void PerMonitorAware() { SetProcessDpiAwarenessContext(new IntPtr(-4)); }
	// the client area of a window as drawn on screen (PW_CLIENTONLY | PW_RENDERFULLCONTENT), 32-bit pixels
	public static int[] Shot(IntPtr h) {
		RECT r; GetClientRect(h, out r); int w = r.R - r.L, ht = r.B - r.T;
		IntPtr screen = GetDC(IntPtr.Zero), dc = CreateCompatibleDC(screen), bmp = CreateCompatibleBitmap(screen, w, ht);
		IntPtr old = SelectObject(dc, bmp);
		PrintWindow(h, dc, 1 | 2);
		SelectObject(dc, old);
		var bi = new BITMAPINFOHEADER { biSize = 40, biWidth = w, biHeight = -ht, biPlanes = 1, biBitCount = 32 };
		var px = new int[w * ht];
		GetDIBits(dc, bmp, 0, (uint)ht, px, ref bi, 0);
		DeleteObject(bmp); DeleteDC(dc); ReleaseDC(IntPtr.Zero, screen);
		return px;
	}
	public static int Differ(int[] a, int[] b) {
		if (a.Length != b.Length) return -1;
		int n = 0; for (int i = 0; i < a.Length; i++) if (((a[i] ^ b[i]) & 0xFFFFFF) != 0) n++;
		return n;
	}
}
'@
[FF]::PerMonitorAware()
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $WM_SETTEXT = 0x000C; $LB_SETCURSEL = 0x0186; $LB_FINDSTRINGEXACT = 0x01A2
$LVM_GETITEMCOUNT = 0x1004; $LVM_GETITEMSTATE = 0x102C; $LVIS_STATEIMAGEMASK = 0xF000
$IDC_LIST_DLGTITLE = 6002; $IDC_LIST_FONTFEATURES = 7203; $IDC_EDIT_FONTFEATURES = 7205; $IDC_FONTFEATURES_FONT_STATIC = 7202
$IDC_COMBO_BOLDWEIGHT = 7209; $CB_SETCURSEL = 0x014E; $CB_GETCURSEL = 0x0147; $CB_GETCOUNT = 0x0146
$IDC_EDIT_FONTFALLBACK = 7213; $SCI_GETFONTFALLBACK = 5109
$IDM_SETTING_PREFERENCE = 48011; $IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002; $IDM_VIEW_DOC_MAP = 44080
$SCI_GETFONTFEATURES = 5107; $SCI_SETCARETSTYLE = 2512; $SCI_STYLEGETWEIGHT = 2064; $SCE_C_WORD = 5; $SCI_GETTECHNOLOGY = 2631

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][FF]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(512); [void][FF]::GetWindowText($h, $sb, 512); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][FF]::EnumWindows({ param($h, $l) $p = 0; [void][FF]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	$script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][FF]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids.ToArray()
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][FF]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
# a view's features (SCI_GETFONTFEATURES copies them into a buffer of this process: read through the length only, then
# compared by asking for them with the expected text's length, the view returning its own length)
function Get-Features([IntPtr] $view) { [int](Send $view $SCI_GETFONTFEATURES) }

Add-Type -AssemblyName System.Drawing
$installedFamilies = [Drawing.Text.InstalledFontCollection]::new().Families.Name
$fontInstalled = $installedFamilies -contains $Font
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-font-features-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
if ($fontInstalled) {
	$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
	$default = [regex]::Match($model, '<WidgetStyle name="Default Style"[^>]*>').Value
	[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model.Replace($default, ($default -replace 'fontName="[^"]*"', "fontName=""$Font""")))
}
$file = Join-Path $settings 'features.cpp'
[IO.File]::WriteAllLines($file, [string[]]@('int zeros = 0000; // O0O 1lI|', 'if (a -> b != c && d >= e || f == g) { return h <= i; }',
	"// $([char]0x4E2D)$([char]0x6587)$([char]0x6DF7)$([char]0x6392) $([char]0x65E5)$([char]0x672C)$([char]0x8A9E)"), [Text.UTF8Encoding]::new($false))
# a CJK font that isn't Windows' usual fallback for these characters (a serif), for the fallback fonts' checks
$cjkFont = @('MS Mincho', 'SimSun', 'MingLiU', 'Batang') | Where-Object { $installedFamilies -contains $_ } | Select-Object -First 1

function Start-Npp {
	$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
	$script:npid = $script:proc.Id
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_CLONE_TO_ANOTHER_VIEW); Start-Sleep -Milliseconds 300
	@(Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [FF]::IsWindowVisible($_) -and ([FF]::GetParent($_) -eq $script:main) })
}
function Stop-Npp {
	if (-not $script:proc.HasExited) { [void][FF]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
}
function Open-FontsPage {
	[void](Send $script:main $WM_COMMAND $IDM_SETTING_PREFERENCE)
	$prefs = $null
	for ($i = 0; $i -lt 50 -and -not $prefs; $i++) {
		Start-Sleep -Milliseconds 100
		$prefs = Get-Tops | Where-Object { [FF]::IsWindowVisible($_) -and [FF]::GetDlgItem($_, $IDC_LIST_DLGTITLE) -ne [IntPtr]::Zero } | Select-Object -First 1
	}
	$list = [FF]::GetDlgItem($prefs, $IDC_LIST_DLGTITLE)
	$i = [FF]::SendMessage($list, $LB_FINDSTRINGEXACT, [IntPtr](-1), 'Fonts').ToInt64(); [void](Send $list $LB_SETCURSEL $i)
	[void](Send $prefs $WM_COMMAND ((1 -shl 16) -bor $IDC_LIST_DLGTITLE) $list.ToInt64()); Start-Sleep -Milliseconds 500 # LBN_SELCHANGE
	Get-Kids $prefs | Where-Object { (Get-Cls $_) -eq '#32770' -and [FF]::GetDlgItem($_, $IDC_LIST_FONTFEATURES) -ne [IntPtr]::Zero } | Select-Object -First 1
}
# the rows of the page's list checked
function Get-Checked([IntPtr] $page) {
	$listView = [FF]::GetDlgItem($page, $IDC_LIST_FONTFEATURES)
	$n = Send $listView $LVM_GETITEMCOUNT
	@(0..([Math]::Max(0, $n - 1)) | Where-Object { $n -gt 0 -and ((Send $listView $LVM_GETITEMSTATE $_ $LVIS_STATEIMAGEMASK) -shr 12) -eq 2 }).Count
}
function Set-BoldWeight([IntPtr] $page, [int] $index) {
	$combo = [FF]::GetDlgItem($page, $IDC_COMBO_BOLDWEIGHT)
	[void](Send $combo $CB_SETCURSEL $index)
	[void](Send $page $WM_COMMAND ((1 -shl 16) -bor $IDC_COMBO_BOLDWEIGHT) $combo.ToInt64()); Start-Sleep -Milliseconds 400 # CBN_SELCHANGE
}
function Set-Fallback([IntPtr] $page, [string] $text) {
	[void][FF]::SendMessage([FF]::GetDlgItem($page, $IDC_EDIT_FONTFALLBACK), $WM_SETTEXT, [IntPtr]::Zero, $text) # EN_CHANGE
	Start-Sleep -Milliseconds 400
}
function Set-Features([IntPtr] $page, [string] $text) {
	[void][FF]::SendMessage([FF]::GetDlgItem($page, $IDC_EDIT_FONTFEATURES), $WM_SETTEXT, [IntPtr]::Zero, $text) # EN_CHANGE
	Start-Sleep -Milliseconds 400
}

try {
	$views = Start-Npp
	Check 'both views shown, no font features by default' (($views.Count -eq 2) -and @($views | Where-Object { (Get-Features $_) -eq 0 }).Count -eq 2) "$($views.Count) views"
	foreach ($v in $views) { [void](Send $v $SCI_SETCARETSTYLE 0) } # no blinking caret in the screenshots
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_DOC_MAP); Start-Sleep -Milliseconds 800
	$map = @(Get-Tops | ForEach-Object { Get-Kids $_ } | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [FF]::IsWindowVisible($_) -and ([FF]::GetParent($_) -ne $script:main) }) | Select-Object -First 1
	$shotView = $views[0]
	Start-Sleep -Milliseconds 300
	$original = [FF]::Shot($shotView)

	$page = Open-FontsPage
	Check 'Preferences > Fonts opened' ($page -ne $null)
	$listView = [FF]::GetDlgItem($page, $IDC_LIST_FONTFEATURES)
	$rows = Send $listView $LVM_GETITEMCOUNT
	$label = Get-Txt ([FF]::GetDlgItem($page, $IDC_FONTFEATURES_FONT_STATIC))
	if ($fontInstalled) {
		# Cascadia Code: calt case frac ordn sinf ss01 (italic) ss02 ss19 ss20 subs sups zero (not its shaping features)
		Check "the list: $Font's features, its italic's ss01 too" (($rows -ge 10) -and ($label -match [regex]::Escape($Font))) "$rows rows; '$label'"
		Check '  checked as drawn: calt only (on by default)' ((Get-Checked $page) -eq 1) "$(Get-Checked $page) checked"
	}
	else { $script:results.Add("INFO  $Font not installed: the list and the drawing not checked ('$label', $rows rows)") }

	# typed: applied once the typing pauses (300 ms), not at each key
	$featuresBox = [FF]::GetDlgItem($page, $IDC_EDIT_FONTFEATURES)
	[void][FF]::SendMessage($featuresBox, $WM_SETTEXT, [IntPtr]::Zero, 'zero') # EN_CHANGE
	$atOnce = Get-Features $shotView
	Start-Sleep -Milliseconds 400
	$got = @($views + $map | Where-Object { $_ } | ForEach-Object { Get-Features $_ })
	Check '"zero" typed: applied once the typing pauses, to both views and the Document Map' (($atOnce -eq 0) -and (@($got | Where-Object { $_ -eq 4 }).Count -eq 3)) "at once $atOnce; then lengths $($got -join ', ')"
	$zero = [FF]::Shot($shotView)
	if ($fontInstalled) {
		Check '  zero checked too' ((Get-Checked $page) -eq 2) "$(Get-Checked $page) checked"
		Check '  the zeros drawn slashed' ([FF]::Differ($original, $zero) -gt 0) "$([FF]::Differ($original, $zero)) pixels changed"
	}

	# with any feature listed, the ones DirectWrite draws by default still drawn: a feature the font hasn't changes nothing
	Set-Features $page 'dlig'
	if ($fontInstalled) { Check '"dlig" (not in the font): drawn as without features, its ligatures kept' ([FF]::Differ($original, [FF]::Shot($shotView)) -eq 0) "$([FF]::Differ($original, [FF]::Shot($shotView))) pixels changed" }

	Set-Features $page 'zero -calt'
	$noCalt = [FF]::Shot($shotView)
	if ($fontInstalled) {
		Check '"zero -calt": calt unchecked' ((Get-Checked $page) -eq 1) "$(Get-Checked $page) checked"
		Check '  the ligatures not drawn (-> != >= ...)' ([FF]::Differ($zero, $noCalt) -gt 0) "$([FF]::Differ($zero, $noCalt)) pixels changed"
	}

	# what isn't a feature is ignored: drawn as "zero" alone
	Set-Features $page 'zero,, ;+zero bogus! s=1 toolong cv1=99999 -'
	Check 'what isn''t a feature ignored: drawn as "zero" alone' ([FF]::Differ($zero, [FF]::Shot($shotView)) -eq 0)

	if ($fontInstalled) {
		# the checks as Scintilla reads the text: a value replaces the sign's, a value it skips leaves the feature as drawn
		$checked = @(foreach ($text in '-zero=1', 'zero=', 'zero=70000', 'zero=00', 'zero=-calt') { Set-Features $page $text; Get-Checked $page }) -join ','
		Check '  checked as Scintilla reads it: -zero=1 on; zero=, zero=70000, zero=00 off; zero=-calt skipped' ($checked -eq '2,1,1,1,1') "checked $checked"

		# a feature unchecked and checked again gets its value back: the list's last row (zero), End and Space
		Set-Features $page 'ss02 zero=2'
		$WM_KEYDOWN = 0x0100; $VK_END = 0x23; $VK_SPACE = 0x20
		[void](Send $listView $WM_KEYDOWN $VK_END); [void](Send $listView $WM_KEYDOWN $VK_SPACE); Start-Sleep -Milliseconds 200
		$unchecked = [FF]::GetText($featuresBox)
		[void](Send $listView $WM_KEYDOWN $VK_SPACE); Start-Sleep -Milliseconds 200
		$rechecked = [FF]::GetText($featuresBox)
		Check '  "zero=2" unchecked: "ss02"; checked again: "ss02 zero=2", applied at once' (($unchecked -eq 'ss02') -and ($rechecked -eq 'ss02 zero=2') -and ((Get-Features $shotView) -eq 11)) "'$unchecked', then '$rechecked'"
	}

	Set-Features $page ''
	Check 'cleared: no features, drawn as at first' (((Get-Features $shotView) -eq 0) -and ([FF]::Differ($original, [FF]::Shot($shotView)) -eq 0))

	# the bold weight: the C++ keywords (SCE_C_WORD, bold in the default theme) SemiBold in both views, then Bold again
	$boldCombo = [FF]::GetDlgItem($page, $IDC_COMBO_BOLDWEIGHT)
	$weights = { @($views | ForEach-Object { [int](Send $_ $SCI_STYLEGETWEIGHT $SCE_C_WORD) }) -join ',' }
	Check 'Bold: 5 weights (Medium to Black), Bold chosen; the keywords 700' (((Send $boldCombo $CB_GETCOUNT) -eq 5) -and ((Send $boldCombo $CB_GETCURSEL) -eq 2) -and ((& $weights) -eq '700,700')) "weights $(& $weights)"
	Set-BoldWeight $page 1
	$semiBold = [FF]::Shot($shotView)
	Check '  SemiBold: the keywords 600 in both views' ((& $weights) -eq '600,600') "weights $(& $weights)"
	if ($fontInstalled) { Check "  drawn lighter ($Font has a SemiBold)" ([FF]::Differ($original, $semiBold) -gt 0) "$([FF]::Differ($original, $semiBold)) pixels changed" }
	if ($Font -eq 'Cascadia Code' -and $fontInstalled) {
		# Medium: DirectWrite draws Cascadia Code (a variable font) heavier at 500, its SemiBold (GDI's Regular: see the end)
		Set-BoldWeight $page 0
		Check "  Medium: 500 ($Font drawn heavier at 500 by DirectWrite)" ((& $weights) -eq '500,500') "weights $(& $weights)"
	}
	Set-BoldWeight $page 2
	Check '  Bold again: 700, drawn as at first' (((& $weights) -eq '700,700') -and ([FF]::Differ($original, [FF]::Shot($shotView)) -eq 0)) "weights $(& $weights)"

	# the fallback fonts: the CJK line (Cascadia Code has none) drawn with the font listed, not Windows' choice; a font
	# DirectWrite doesn't know left out
	$fallbackBox = [FF]::GetDlgItem($page, $IDC_EDIT_FONTFALLBACK)
	$windowsFallback = [FF]::Shot($shotView)
	if ($cjkFont -and $fontInstalled) {
		Set-Fallback $page "No Such Font; $cjkFont"
		$listed = [FF]::Shot($shotView)
		$fallbacks = @($views | ForEach-Object { [int](Send $_ $SCI_GETFONTFALLBACK) })
		Check "fallback fonts ""No Such Font; $cjkFont"": both views at once, the CJK drawn with $cjkFont" (((@($fallbacks | Where-Object { $_ -eq ("No Such Font; $cjkFont").Length }).Count -eq 2)) -and ([FF]::Differ($windowsFallback, $listed) -gt 0)) "lengths $($fallbacks -join ', '); $([FF]::Differ($windowsFallback, $listed)) pixels changed"
		Set-Fallback $page 'No Such Font'
		Check '  a font DirectWrite doesn''t know alone: Windows'' fallback' ([FF]::Differ($windowsFallback, [FF]::Shot($shotView)) -eq 0)
		# a font of a weight of the font lists, a GDI family name: its family, as DirectWrite knows it
		Set-Fallback $page "$Font SemiBold; $cjkFont"
		Check "  ""$Font SemiBold"" (a GDI name) given as $Font" ((Send $shotView $SCI_GETFONTFALLBACK) -eq ("$Font, $cjkFont").Length) "length $(Send $shotView $SCI_GETFONTFALLBACK)"
	}
	else { $script:results.Add("INFO  no serif CJK font (MS Mincho, SimSun, MingLiU, Batang) or no $Font`: the fallback fonts' drawing not checked") }
	Set-Fallback $page ''
	Check '  cleared: Windows'' fallback' (((Send $shotView $SCI_GETFONTFALLBACK) -eq 0) -and ([FF]::Differ($windowsFallback, [FF]::Shot($shotView)) -eq 0))

	Set-Features $page 'ss02 zero'
	Set-BoldWeight $page 1
	Set-Fallback $page 'Segoe UI Emoji'
	Stop-Npp
	$config = Get-Content -LiteralPath (Join-Path $settings 'config.xml') -Raw
	Check 'saved: config.xml fontFeatures="ss02 zero" boldWeight="600" fontFallback="Segoe UI Emoji"' (($config -match 'fontFeatures="ss02 zero"') -and ($config -match 'boldWeight="600"') -and ($config -match 'fontFallback="Segoe UI Emoji"'))
	$views = Start-Npp
	Check '  read back at the next start: both views' ((@($views | Where-Object { ((Get-Features $_) -eq 9) -and ((Send $_ $SCI_GETFONTFALLBACK) -eq 14) }).Count -eq 2) -and ((& $weights) -eq '600,600')) "lengths $(@($views | ForEach-Object { Get-Features $_ }) -join ', '); weights $(& $weights)"
	Stop-Npp

	if ($Font -eq 'Cascadia Code' -and $fontInstalled) {
		# Medium with GDI (an older config.xml): GDI's family "Cascadia Code" is Regular and Bold, so Medium would draw its
		# Regular: Bold
		$configPath = Join-Path $settings 'config.xml'
		$config = [IO.File]::ReadAllText($configPath)
		[IO.File]::WriteAllText($configPath, ($config -replace 'boldWeight="\d+"', 'boldWeight="500"' -replace 'writeTechnologyEngine="\d+"', 'writeTechnologyEngine="0"'))
		$views = Start-Npp
		$technologies = @($views | ForEach-Object { Send $_ $SCI_GETTECHNOLOGY }) -join ','
		Check "Medium with GDI: Bold, 700 (GDI's $Font is Regular and Bold)" (($technologies -eq '0,0') -and ((& $weights) -eq '700,700')) "technologies $technologies; weights $(& $weights)"
		Stop-Npp
	}
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
