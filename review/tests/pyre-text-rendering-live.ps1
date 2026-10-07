# App-level test (review harness), Pyre909 builds only: with DirectWrite, each Antialiasing choice and DirectWrite mode of
# Preferences > Editing 1 > Text Rendering changes the text at once, without restarting (test round of STATUS.md).
# Drives the real combo box handlers (CB_SETCURSEL, then the CBN_SELCHANGE notification a click sends), then reads from
# both views of the document (main and cloned) the font quality and the rendering parameters Scintilla got, and
# compares a screenshot of the main view (PrintWindow) with the one of the previous choice. The choices go in an order
# where each one draws differently from the one before (Automatic, Natural and Symmetric can draw alike for a font, so
# GDI classic comes between them).
# Contract of review\tests: -Exe <notepad++.exe>; PASS/FAIL lines; last line "<n> checks, <m> failed".
param([Parameter(Mandatory)] [string] $Exe,
	[string] $TestFile = (Join-Path $PSScriptRoot '..\..\vm\weights.cpp'))
$ErrorActionPreference = 'Stop'
if (-not [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($Exe)).Contains('Pyre909 build')) {
	'INFO  not a Pyre909 build: skipped'; '0 checks, 0 failed'; exit
}
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class TL {
	public delegate bool EnumProc(IntPtr h, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
	[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
	[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
	[DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint action, uint param, out uint value, uint winIni);
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
[TL]::PerMonitorAware()
$WM_CLOSE = 0x0010; $WM_COMMAND = 0x0111; $CB_SETCURSEL = 0x014E; $CB_GETCURSEL = 0x0147
$IDC_COMBO_TEXTANTIALIASING = 6282; $IDC_COMBO_TEXTRENDERINGMODE = 6284
$IDM_SETTING_PREFERENCE = 48011; $IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002
$SCI_GETFONTQUALITY = 2612; $SCI_GETTECHNOLOGY = 2631; $SCI_GETFONTRENDERINGPARAMETER = 5102
$SC_FONTRENDERING_CLEARTYPELEVEL = 2; $SC_FONTRENDERING_RENDERINGMODE = 3

$script:results = [Collections.Generic.List[string]]::new(); $script:fails = 0
function Check([string] $name, [bool] $ok, [string] $detail = '') {
	if (-not $ok) { $script:fails++ }
	$script:results.Add(("{0}  {1}{2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $(if ($detail) { "  [$detail]" } else { '' })))
}
function Get-Cls([IntPtr] $h) { $sb = [Text.StringBuilder]::new(64); [void][TL]::GetClassName($h, $sb, 64); $sb.ToString() }
function Get-Txt([IntPtr] $h) { $sb = [Text.StringBuilder]::new(256); [void][TL]::GetWindowText($h, $sb, 256); $sb.ToString() }
function Get-Tops {
	$script:acc = [Collections.Generic.List[IntPtr]]::new()
	[void][TL]::EnumWindows({ param($h, $l) $p = 0; [void][TL]::GetWindowThreadProcessId($h, [ref]$p); if ($p -eq $script:npid) { $script:acc.Add($h) }; $true }, [IntPtr]::Zero)
	$script:acc.ToArray()
}
function Get-Kids([IntPtr] $parent) {
	$script:kids = [Collections.Generic.List[IntPtr]]::new()
	[void][TL]::EnumChildWindows($parent, { param($h, $l) $script:kids.Add($h); $true }, [IntPtr]::Zero)
	$script:kids.ToArray()
}
function Send([IntPtr] $h, [int] $msg, [long] $w = 0, [long] $l = 0) { $r = [IntPtr]::Zero; [void][TL]::SendMessageTimeout($h, $msg, [IntPtr]$w, [IntPtr]$l, 2, 5000, [ref]$r); $r.ToInt64() }
function Select-Item([IntPtr] $combo, [int] $id, [int] $idx) {
	[void][TL]::SendMessage($combo, $CB_SETCURSEL, [IntPtr]$idx, [IntPtr]::Zero)
	[void](Send $script:editing $WM_COMMAND ((1 -shl 16) -bor $id) $combo.ToInt64())   # MAKEWPARAM(id, CBN_SELCHANGE)
	Start-Sleep -Milliseconds 400
}
# what Scintilla got in a view: quality, ClearType level, rendering mode
function Get-State([IntPtr] $view) {
	'{0}/{1}/{2}' -f [int](Send $view $SCI_GETFONTQUALITY), [int](Send $view $SCI_GETFONTRENDERINGPARAMETER $SC_FONTRENDERING_CLEARTYPELEVEL), [int](Send $view $SCI_GETFONTRENDERINGPARAMETER $SC_FONTRENDERING_RENDERINGMODE)
}

# the quality "Follow Windows" gives with DirectWrite: smoothing off 1, Standard 2, ClearType 0 (see getWindowsFontQuality)
$smoothing = [uint32]0; [void][TL]::SystemParametersInfo(0x004A, 0, [ref]$smoothing, 0)
$type = [uint32]0; [void][TL]::SystemParametersInfo(0x200A, 0, [ref]$type, 0)
$followWindows = if (-not $smoothing) { 1 } elseif ($type -eq 1) { 2 } else { 0 }

$settings = Join-Path ([IO.Path]::GetTempPath()) ('npp-review\pyre-text-rendering-live-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $settings | Out-Null
Copy-Item $TestFile $settings; $file = Join-Path $settings (Split-Path $TestFile -Leaf)
$proc = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$settings", '-titleAdd=REVIEW-TEST', $file -PassThru
$script:npid = $proc.Id
try {
	for ($i = 0; $i -lt 100; $i++) { $proc.Refresh(); if ($proc.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 100 }
	$script:main = $proc.MainWindowHandle; Start-Sleep -Milliseconds 800
	[void](Send $script:main $WM_COMMAND $IDM_VIEW_CLONE_TO_ANOTHER_VIEW); Start-Sleep -Milliseconds 300
	$views = @(Get-Kids $script:main | Where-Object { (Get-Cls $_) -eq 'Scintilla' -and [TL]::IsWindowVisible($_) -and ([TL]::GetParent($_) -eq $script:main) })
	Check 'both views shown, in DirectWrite (fresh settings default)' (($views.Count -eq 2) -and @($views | Where-Object { (Send $_ $SCI_GETTECHNOLOGY) -eq 1 }).Count -eq 2) "$($views.Count) views"
	$shotView = $views[0]
	[void](Send $shotView 2512 0)   # SCI_SETCARETSTYLE CARETSTYLE_INVISIBLE: no blinking caret in the screenshots
	Start-Sleep -Milliseconds 300
	$a = [TL]::Shot($shotView); Start-Sleep -Milliseconds 700; $b = [TL]::Shot($shotView)
	$still = [TL]::Differ($a, $b)
	Check 'control: two screenshots without a change are the same' ($still -eq 0) "$still pixels changed"

	[void](Send $script:main $WM_COMMAND $IDM_SETTING_PREFERENCE)
	for ($i = 0; $i -lt 50 -and -not $script:editing; $i++) {
		Start-Sleep -Milliseconds 100
		$pref = Get-Tops | Where-Object { (Get-Cls $_) -eq '#32770' -and (Get-Txt $_) -eq 'Preferences' } | Select-Object -First 1
		if ($pref) { $script:editing = Get-Kids $pref | Where-Object { [TL]::GetDlgItem($_, $IDC_COMBO_TEXTANTIALIASING) -ne [IntPtr]::Zero } | Select-Object -First 1 }
	}
	$aaCombo = [TL]::GetDlgItem($script:editing, $IDC_COMBO_TEXTANTIALIASING)
	$modeCombo = [TL]::GetDlgItem($script:editing, $IDC_COMBO_TEXTRENDERINGMODE)
	Check 'Preferences > Editing 1 Text Rendering boxes found' (($aaCombo -ne [IntPtr]::Zero) -and ($modeCombo -ne [IntPtr]::Zero))
	Check 'the DirectWrite mode box has 4 items' ((Send $modeCombo 0x0146) -eq 4)   # CB_GETCOUNT

	# expected state: quality / ClearType level / rendering mode (-1: the monitor's)
	$aaNames = 'Follow Windows', 'ClearType', 'ClearType (less color fringing)', 'Grayscale', 'None'
	$aaQuality = $followWindows, 3, 3, 2, 1
	$modeNames = 'Automatic', 'Natural', 'Symmetric', 'GDI classic'
	$modeValues = -1, 4, 5, 2
	$aa = 0; $mode = 0
	$before = [TL]::Shot($shotView)
	$steps = @(
		@('aa', 1), @('aa', 3), @('aa', 4), @('aa', 2), @('aa', 1), @('aa', 4), @('aa', 0),
		@('mode', 3), @('mode', 1), @('mode', 3), @('mode', 2), @('mode', 3), @('mode', 0)
	)
	foreach ($step in $steps) {
		$prevState = '{0}/{1}/{2}' -f $aaQuality[$aa], $(if ($aa -eq 2) { 50 } else { -1 }), $modeValues[$mode]
		if ($step[0] -eq 'aa') { $aa = $step[1]; Select-Item $aaCombo $IDC_COMBO_TEXTANTIALIASING $aa; $name = "Antialiasing $($aaNames[$aa])" }
		else { $mode = $step[1]; Select-Item $modeCombo $IDC_COMBO_TEXTRENDERINGMODE $mode; $name = "DirectWrite mode $($modeNames[$mode])" }
		$expected = '{0}/{1}/{2}' -f $aaQuality[$aa], $(if ($aa -eq 2) { 50 } else { -1 }), $modeValues[$mode]
		$states = @($views | ForEach-Object { Get-State $_ })
		Check "$name`: both views at once" (@($states | Where-Object { $_ -eq $expected }).Count -eq 2) "quality/level/mode $($states -join ', '), expected $expected"
		$after = [TL]::Shot($shotView)
		$changed = [TL]::Differ($before, $after)
		if ($expected -ne $prevState) { Check "  the text redrawn differently" ($changed -gt 0) "$changed pixels changed" }
		$before = $after
	}
}
finally {
	if (-not $proc.HasExited) { [void][TL]::PostMessage($script:main, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero); if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force } }
	$script:results
	"settings folder: $settings"
	"{0} checks, {1} failed" -f $script:results.Count, $script:fails
}
