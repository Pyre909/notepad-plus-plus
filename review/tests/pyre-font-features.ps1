# App-level test (review harness), Pyre909 builds only: Preferences > Fonts, the fonts' OpenType features (config.xml
# fontFeatures, pyre's SCI_SETFONTFEATURES). Cascadia Code (Windows 11) as Default Style: the page lists its features
# (its stylistic sets, the italic's ss01 too, zero, calt...), checked as drawn (calt on by default); a list typed in the
# page's text applies at once to both views of a document and the Document Map, checks the list, and draws differently
# ("zero": a slashed zero; "-calt": no ligatures); what isn't a feature is ignored; cleared, the text is drawn as before;
# saved in config.xml and read back at the next start. Without Cascadia Code, the drawing and list checks are skipped.
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
$IDM_SETTING_PREFERENCE = 48011; $IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002; $IDM_VIEW_DOC_MAP = 44080
$SCI_GETFONTFEATURES = 5107; $SCI_SETCARETSTYLE = 2512

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

$fontInstalled = @(Get-ChildItem "$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -ErrorAction SilentlyContinue |
	Where-Object { $_.BaseName -eq ($Font -replace ' ', '') }).Count -gt 0
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-font-features-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
if ($fontInstalled) {
	$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
	$default = [regex]::Match($model, '<WidgetStyle name="Default Style"[^>]*>').Value
	[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model.Replace($default, ($default -replace 'fontName="[^"]*"', "fontName=""$Font""")))
}
$file = Join-Path $settings 'features.cpp'
[IO.File]::WriteAllLines($file, [string[]]@('int zeros = 0000; // O0O 1lI|', 'if (a -> b != c && d >= e || f == g) { return h <= i; }'))

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

	Set-Features $page 'zero'
	$got = @($views + $map | Where-Object { $_ } | ForEach-Object { Get-Features $_ })
	Check '"zero" typed: both views and the Document Map at once' ((@($got | Where-Object { $_ -eq 4 }).Count -eq 3)) "lengths $($got -join ', ')"
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

	Set-Features $page ''
	Check 'cleared: no features, drawn as at first' (((Get-Features $shotView) -eq 0) -and ([FF]::Differ($original, [FF]::Shot($shotView)) -eq 0))

	Set-Features $page 'ss02 zero'
	Stop-Npp
	$config = Get-Content -LiteralPath (Join-Path $settings 'config.xml') -Raw
	Check 'saved: config.xml fontFeatures="ss02 zero"' ($config -match 'fontFeatures="ss02 zero"')
	$views = Start-Npp
	Check '  read back at the next start: both views' (@($views | Where-Object { (Get-Features $_) -eq 9 }).Count -eq 2) "lengths $(@($views | ForEach-Object { Get-Features $_ }) -join ', ')"
	Stop-Npp
}
finally {
	foreach ($q in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe -and $_.MainWindowTitle -match 'REVIEW-TEST' })) { Stop-Process -Id $q.Id -Force }
	$script:results
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notmatch '^INFO' }).Count, $script:fails
}
