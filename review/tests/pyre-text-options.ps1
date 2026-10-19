# App-level test (review harness), Pyre909 builds only: the options of 2026-10-19.
# - The edit views' layout: the page layout cache, layout threads, multiple-phase drawing.
# - Preferences > Editing 1 > Text Rendering: "Line spacing" and "Font ligatures", applied at once to both views of a
#   document (main and cloned) and not to the Document Map, saved in config.xml and read back at the next start; with
#   the line spacing Normal, an extra ascent a plugin set is kept.
# Ligatures need a font that has some: Cascadia Code (Windows 11) as Default Style; without it, the drawing checks are
# skipped. Drives the real controls (CB_SETCURSEL / BM_SETCHECK, then the notification a click sends), reads what
# Scintilla got (SCI_GETEXTRAASCENT, SCI_GETFONTRENDERINGPARAMETER) and compares screenshots of the main view.
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe, [string] $Font = 'Cascadia Code')
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class TO {
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
	[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
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
[TO]::PerMonitorAware()
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $CB_SETCURSEL = 0x014E; $CB_GETCOUNT = 0x0146; $BM_SETCHECK = 0x00F1; $BM_GETCHECK = 0x00F0
$IDC_COMBO_LINESPACING = 6288; $IDC_CHECK_FONTLIGATURES = 6289
$IDM_SETTING_PREFERENCE = 48011; $IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002; $IDM_VIEW_DOC_MAP = 44080
$SCI_GETLAYOUTCACHE = 2273; $SCI_GETLAYOUTTHREADS = 2776; $SCI_GETPHASESDRAW = 2673; $SCI_GETTECHNOLOGY = 2631
$SCI_GETEXTRAASCENT = 2526; $SCI_GETEXTRADESCENT = 2528; $SCI_TEXTHEIGHT = 2279; $SCI_SETCARETSTYLE = 2512
$SCI_GETFONTRENDERINGPARAMETER = 5102; $SC_FONTRENDERING_LIGATURES = 5

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][TO]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][TO]::GetWindowText($h, $sb, 256); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][TO]::EnumWindows({ param($h, $l) $p = 0; [void][TO]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	$script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][TO]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids.ToArray()
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][TO]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }

$fontInstalled = @(Get-ChildItem "$env:WINDIR\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -ErrorAction SilentlyContinue |
	Where-Object { $_.BaseName -eq ($Font -replace ' ', '') }).Count -gt 0
$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-text-options-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
if ($fontInstalled) {
	# the font as Default Style, in a stylers.xml made from the model next to the exe
	$model = [IO.File]::ReadAllText((Join-Path (Split-Path $Exe) 'stylers.model.xml'))
	$default = [regex]::Match($model, '<WidgetStyle name="Default Style"[^>]*>').Value
	[IO.File]::WriteAllText((Join-Path $settings 'stylers.xml'), $model.Replace($default, ($default -replace 'fontName="[^"]*"', "fontName=""$Font""")))
}
$file = Join-Path $settings 'ligatures.cpp'
[IO.File]::WriteAllLines($file, [string[]]@('if (a -> b != c && d >= e || f == g) { return h <= i; }', 'auto x = y => z; // www === ::'))

# starts Notepad++ on the test file with both views of it shown; returns the views
function Start-Npp {
	$script:proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
	$script:npid = $script:proc.Id; $script:editing = $null
	for ($i = 0; $i -lt 100; $i++) { $script:proc.Refresh(); if ($script:proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $script:proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_CLONE_TO_ANOTHER_VIEW); Start-Sleep -Milliseconds 300
	@(Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [TO]::IsWindowVisible($_) -and ([TO]::GetParent($_) -eq $script:main) })
}
function Stop-Npp {
	if (-not $script:proc.HasExited) { [void][TO]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force } }
}
# extra ascent/descent of a view
function Get-Spacing([IntPtr] $view) { '{0}/{1}' -f [int](Send $view $SCI_GETEXTRAASCENT), [int](Send $view $SCI_GETEXTRADESCENT) }
# the extra ascent/descent a line spacing of n pixels at 96 DPI gives at the view's DPI
# pixels at 96 DPI scaled to a window's DPI, rounded like MulDiv (DPIManagerV2::scale)
function Scale([IntPtr] $h, [int] $n) { [int][math]::Round($n * [TO]::GetDpiForWindow($h) / 96, [MidpointRounding]::AwayFromZero) }
function Expected-Spacing([IntPtr] $view, [int] $n) { $px = Scale $view $n; '{0}/{1}' -f [math]::Floor($px / 2), ($px - [math]::Floor($px / 2)) }

try {
	$views = Start-Npp
	Check 'both views shown, in DirectWrite (fresh settings default)' (($views.Count -eq 2) -and @($views | Where-Object { (Send $_ $SCI_GETTECHNOLOGY) -eq 1 }).Count -eq 2) "$($views.Count) views"

	# the layout options of the edit views
	$threadsExpected = [Math]::Min([Environment]::ProcessorCount, 8)   # at most 8 (ScintillaEditView::init)
	$layouts = @($views | ForEach-Object { '{0}/{1}/{2}' -f [int](Send $_ $SCI_GETLAYOUTCACHE), [int](Send $_ $SCI_GETLAYOUTTHREADS), [int](Send $_ $SCI_GETPHASESDRAW) })
	Check 'edit views: page layout cache, the processor''s threads (8 at most), multiple phases' (@($layouts | Where-Object { $_ -eq "2/$threadsExpected/2" }).Count -eq 2) "cache/threads/phases $($layouts -join ', '), expected 2/$threadsExpected/2"
	Check 'defaults: no line spacing, the fonts'' ligatures' (@($views | Where-Object { (Get-Spacing $_) -eq '0/0' -and (Send $_ $SCI_GETFONTRENDERINGPARAMETER $SC_FONTRENDERING_LIGATURES) -eq -1 }).Count -eq 2)

	$shotView = $views[0]
	foreach ($v in $views) { [void](Send $v $SCI_SETCARETSTYLE 0) }   # CARETSTYLE_INVISIBLE: no blinking caret in the screenshots
	Start-Sleep -Milliseconds 300
	$a = [TO]::Shot($shotView); Start-Sleep -Milliseconds 700; $b = [TO]::Shot($shotView)
	Check 'control: two screenshots without a change are the same' ([TO]::Differ($a, $b) -eq 0)
	$original = $b
	$heightBefore = [int](Send $shotView $SCI_TEXTHEIGHT 0)

	[void](Send $script:main $WM_COMMAND $IDM_SETTING_PREFERENCE)
	for ($i = 0; $i -lt 50 -and -not $script:editing; $i++) {
		Start-Sleep -Milliseconds 100
		$pref = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1
		if ($pref) { $script:editing = Get-Kids $pref | Where-Object { [TO]::GetDlgItem($_, $IDC_COMBO_LINESPACING) -ne [IntPtr]::Zero } | Select-Object -First 1 }
	}
	$spacingCombo = [TO]::GetDlgItem($script:editing, $IDC_COMBO_LINESPACING)
	$ligatureBox = [TO]::GetDlgItem($script:editing, $IDC_CHECK_FONTLIGATURES)
	Check 'Preferences > Editing 1: Line spacing (11 items) and Font ligatures (checked)' (($spacingCombo -ne [IntPtr]::Zero) -and ((Send $spacingCombo $CB_GETCOUNT) -eq 11) -and ((Send $ligatureBox $BM_GETCHECK) -eq 1))

	# with the line spacing Normal, an extra ascent a plugin set is kept when the Text Rendering settings apply again
	[void](Send $shotView 2525 2)   # SCI_SETEXTRAASCENT, as a plugin would
	foreach ($state in 0, 1) {
		[void](Send $ligatureBox $BM_SETCHECK $state)
		[void](Send $script:editing $WM_COMMAND $IDC_CHECK_FONTLIGATURES $ligatureBox.ToInt64())   # BN_CLICKED
	}
	Start-Sleep -Milliseconds 300
	Check 'line spacing Normal: an extra ascent a plugin set is kept' ((Get-Spacing $shotView) -eq '2/0') "ascent/descent $(Get-Spacing $shotView)"
	[void](Send $shotView 2525 0)

	# Line spacing +3: both views at once, the lines taller, the text drawn elsewhere
	[void](Send $spacingCombo $CB_SETCURSEL 3)
	[void](Send $script:editing $WM_COMMAND ((1 -shl 16) -bor $IDC_COMBO_LINESPACING) $spacingCombo.ToInt64())   # CBN_SELCHANGE
	Start-Sleep -Milliseconds 400
	$spacings = @($views | ForEach-Object { Get-Spacing $_ }); $expected = Expected-Spacing $shotView 3
	Check 'Line spacing +3: both views at once' (@($spacings | Where-Object { $_ -eq $expected }).Count -eq 2) "ascent/descent $($spacings -join ', '), expected $expected"
	$heightAfter = [int](Send $shotView $SCI_TEXTHEIGHT 0)
	Check '  the lines taller by the spacing' ($heightAfter -eq $heightBefore + (Scale $shotView 3)) "$heightBefore -> $heightAfter pixels"
	$spaced = [TO]::Shot($shotView)
	Check '  the text redrawn' ([TO]::Differ($original, $spaced) -gt 0)

	# the Document Map: no line spacing (a miniature of the document)
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_DOC_MAP); Start-Sleep -Milliseconds 800
	$map = @(Get-Tops | ForEach-Object { Get-Kids $_ } | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [TO]::IsWindowVisible($_) -and ([TO]::GetParent($_) -ne $script:main) }) | Select-Object -First 1
	Check 'Document Map shown, without line spacing' ($map -and ((Get-Spacing $map) -eq '0/0')) $(if ($map) { "ascent/descent $(Get-Spacing $map)" } else { 'no map view' })
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_DOC_MAP); Start-Sleep -Milliseconds 300

	# Font ligatures off: both views at once; on again: drawn as before
	[void](Send $ligatureBox $BM_SETCHECK 0)
	[void](Send $script:editing $WM_COMMAND $IDC_CHECK_FONTLIGATURES $ligatureBox.ToInt64())   # BN_CLICKED
	Start-Sleep -Milliseconds 400
	$ligs = @($views | ForEach-Object { [int](Send $_ $SCI_GETFONTRENDERINGPARAMETER $SC_FONTRENDERING_LIGATURES) })
	Check 'Font ligatures off: both views at once' (@($ligs | Where-Object { $_ -eq 0 }).Count -eq 2) "ligatures parameter $($ligs -join ', ')"
	$noLigatures = [TO]::Shot($shotView)
	if ($fontInstalled) { Check "  $Font's ligatures not drawn" ([TO]::Differ($spaced, $noLigatures) -gt 0) "$([TO]::Differ($spaced, $noLigatures)) pixels changed" }
	else { $script:results.Add("INFO  $Font not installed: drawing of the ligatures not checked") }
	[void](Send $ligatureBox $BM_SETCHECK 1)
	[void](Send $script:editing $WM_COMMAND $IDC_CHECK_FONTLIGATURES $ligatureBox.ToInt64())
	Start-Sleep -Milliseconds 400
	$ligs = @($views | ForEach-Object { [int](Send $_ $SCI_GETFONTRENDERINGPARAMETER $SC_FONTRENDERING_LIGATURES) })
	Check 'Font ligatures on again: the fonts'' own' (@($ligs | Where-Object { $_ -eq -1 }).Count -eq 2) "ligatures parameter $($ligs -join ', ')"
	Check '  drawn as before turning them off' ([TO]::Differ($spaced, [TO]::Shot($shotView)) -eq 0)

	# saved, then read back at the next start: spacing +5, ligatures off
	[void](Send $spacingCombo $CB_SETCURSEL 5)
	[void](Send $script:editing $WM_COMMAND ((1 -shl 16) -bor $IDC_COMBO_LINESPACING) $spacingCombo.ToInt64())
	[void](Send $ligatureBox $BM_SETCHECK 0)
	[void](Send $script:editing $WM_COMMAND $IDC_CHECK_FONTLIGATURES $ligatureBox.ToInt64())
	Start-Sleep -Milliseconds 300
	Stop-Npp
	$view = [regex]::Match([IO.File]::ReadAllText((Join-Path $settings 'config.xml')), '<GUIConfig name="ScintillaPrimaryView"[^>]*>').Value
	Check 'config.xml: lineSpacing="5" fontLigatures="no"' (($view -match 'lineSpacing="5"') -and ($view -match 'fontLigatures="no"'))
	$views = Start-Npp
	$expected = Expected-Spacing $views[0] 5
	$state = @($views | ForEach-Object { '{0} {1}' -f (Get-Spacing $_), [int](Send $_ $SCI_GETFONTRENDERINGPARAMETER $SC_FONTRENDERING_LIGATURES) })
	Check 'next start: both views with the saved spacing and ligatures off' (@($state | Where-Object { $_ -eq "$expected 0" }).Count -eq 2) "$($state -join ', '), expected $expected 0"
}
finally {
	Stop-Npp
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f @($script:results | Where-Object { $_ -notlike 'INFO*' }).Count, $script:fails
}
