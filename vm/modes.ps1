# Compare the DirectWrite rendering modes of pyre's Text Rendering settings at editor sizes.
# For each font (config.xml Global override, restart), zoom and quality, sets each mode with SCI_SETFONTRENDERINGPARAMETER
# on the edit view, screenshots it (PrintWindow) and diffs it against Automatic (Adaptive also against Natural).
# Windows PowerShell 5.1: powershell.exe -NoProfile -ExecutionPolicy Bypass -File modes.ps1 [-Fonts ...] [-Zooms ...]
param(
	[string] $Exe = 'C:\Users\stephensamaniego\src\npp\PowerEditor\binarm64\Notepad++.exe',
	[string] $Dir = 'C:\npp-modetest',
	[string[]] $Fonts = @('Consolas', 'Cascadia Mono', 'Courier New', 'Segoe UI'),
	[int[]] $Zooms = @(-1, 0, 2, 4), # 10 pt base: 9, 10, 12, 14 pt
	[string] $Out = "$PSScriptRoot\shots\modes" # PNGs and modes.csv (not committed: vm\modes.csv is the 2026-10-06 run)
)
$ErrorActionPreference = 'Stop'
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Text; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class M {
  [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, int m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  public struct RECT { public int L, T, R, B; }
  public static IntPtr Top(uint pid) {
    SetProcessDpiAwarenessContext(new IntPtr(-4));
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p); var sb = new StringBuilder(64); GetClassName(h, sb, 64);
      if (p == pid && sb.ToString() == "Notepad++" && IsWindowVisible(h)) { found = h; return false; } return true; }, IntPtr.Zero);
    return found;
  }
  public static IntPtr Editor(IntPtr top) {
    IntPtr best = IntPtr.Zero; int area = 0;
    EnumChildWindows(top, (h, l) => { var sb = new StringBuilder(64); GetClassName(h, sb, 64);
      if (sb.ToString() == "Scintilla" && IsWindowVisible(h)) { RECT r; GetClientRect(h, out r); int a = (r.R - r.L) * (r.B - r.T); if (a > area) { area = a; best = h; } }
      return true; }, IntPtr.Zero);
    return best;
  }
  public static Bitmap Shot(IntPtr h, int x0) {
    RECT r; GetClientRect(h, out r); var bmp = new Bitmap(r.R - r.L, r.B - r.T, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 1 | 2); g.ReleaseHdc(dc); }
    var crop = bmp.Clone(new Rectangle(x0, 0, Math.Min(700, bmp.Width - x0), Math.Min(260, bmp.Height)), PixelFormat.Format32bppArgb);
    bmp.Dispose(); return crop;
  }
  static int[] Px(Bitmap b) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var a = new int[b.Width * b.Height]; Marshal.Copy(d.Scan0, a, 0, a.Length); b.UnlockBits(d); return a;
  }
  // pixels that differ, the mean absolute channel difference over the differing pixels, the largest one, ink of each
  public static double[] Diff(Bitmap a, Bitmap b) {
    var pa = Px(a); var pb = Px(b); long n = 0, sum = 0; int max = 0; long inkA = 0, inkB = 0;
    for (int i = 0; i < pa.Length; i++) {
      int d = 0;
      for (int s = 0; s < 24; s += 8) { int ca = (pa[i] >> s) & 255, cb = (pb[i] >> s) & 255; d += Math.Abs(ca - cb); inkA += 255 - ca; inkB += 255 - cb; }
      if (d > 0) { n++; sum += d; if (d > max) max = d; }
    }
    return new double[] { n, n > 0 ? (double)sum / n / 3 : 0, max / 3.0, inkA / 3000.0, inkB / 3000.0 };
  }
}
'@
$SCI_SETFONTRENDERINGPARAMETER = 5101; $RENDERINGMODE = 3
$modes = [ordered]@{ Automatic = -1; Natural = 4; Symmetric = 5; GdiClassic = 2; Adaptive = 100 }
$qualities = [ordered]@{ ClearType = 3; Grayscale = 2 } # SC_EFF_QUALITY_LCD_OPTIMIZED, SC_EFF_QUALITY_ANTIALIASED

New-Item -ItemType Directory -Force $Dir, $Out | Out-Null
$sample = Join-Path $Dir 'sample.cpp'
@'
// Rendering mode sample: Hamburgefonstiv 0123456789 il1I|O0 {}[]()<>;:,.
int ScintillaEditView::getCurrentLineNumber(const Buffer* buffer, bool isZeroBased) const
{
	for (size_t i = 0, len = _styleFonts.size(); i < len; ++i)
		if (_styleFonts[i].technology != technology && i % 3 == 0) return -1; // "quoted text"
	auto lambda = [&](int x) { return x * 2 + static_cast<int>(wcslen(L"wide string")); };
	const std::wstring path = L"C:\\Program Files\\Notepad++\\notepad++.exe";
	#define MACRO(a, b) ((a) > (b) ? (a) : (b))
	The quick brown fox jumps over the lazy dog. WAVE Type AV To Ty fi fl ff
}
'@ | Set-Content -Encoding UTF8 $sample

function Start-Npp {
	$p = Start-Process $Exe -ArgumentList '-multiInst', '-nosession', "-settingsDir=$Dir", $sample -PassThru
	for ($i = 0; $i -lt 60; $i++) { Start-Sleep -Milliseconds 250; $t = [M]::Top([uint32]$p.Id); if ($t -ne [IntPtr]::Zero) { break } }
	if ($t -eq [IntPtr]::Zero) { throw 'no window' }
	Start-Sleep -Milliseconds 1500
	return @{ Process = $p; Top = $t }
}
function Stop-Npp($n) { [void][M]::PostMessage($n.Top, 0x10, [IntPtr]0, [IntPtr]0); $n.Process.WaitForExit(15000) | Out-Null; if (!$n.Process.HasExited) { $n.Process.Kill() } }

# first start: config.xml written at exit
$cfg = Join-Path $Dir 'config.xml'
if (!(Test-Path $cfg)) { Stop-Npp (Start-Npp) }

$rows = @()
foreach ($font in $Fonts) {
	[xml]$x = Get-Content -Raw $cfg
	$go = $x.NotepadPlus.GUIConfigs.GUIConfig | Where-Object { $_.name -eq 'globalOverride' }
	$go.SetAttribute('font', 'yes'); $go.SetAttribute('fontSize', 'yes')
	$go.SetAttribute('forcedFontName', $font); $go.SetAttribute('forcedFontSize', '10')
	$x.Save($cfg)

	$n = Start-Npp
	$h = [M]::Editor($n.Top)
	$tech = [int][M]::SendMessage($h, 2631, [IntPtr]0, [IntPtr]0)
	if ($tech -eq 0) { Stop-Npp $n; throw "GDI technology: set DirectWrite in $cfg" }
	$dpi = [M]::GetDpiForWindow($h)
	[void][M]::SendMessage($h, 2512, [IntPtr]0, [IntPtr]0) # SCI_SETCARETSTYLE CARETSTYLE_INVISIBLE: no blinking caret in the shots
	$x0 = 0; foreach ($m in 0..4) { $x0 += [int][M]::SendMessage($h, 2243, [IntPtr]$m, [IntPtr]0) }
	foreach ($q in $qualities.Keys) {
		[void][M]::SendMessage($h, 2611, [IntPtr]$qualities[$q], [IntPtr]0) # SCI_SETFONTQUALITY
		foreach ($z in $Zooms) {
			[void][M]::SendMessage($h, 2373, [IntPtr]$z, [IntPtr]0) # SCI_SETZOOM
			$shots = [ordered]@{}
			foreach ($mode in $modes.Keys) {
				[void][M]::SendMessage($h, $SCI_SETFONTRENDERINGPARAMETER, [IntPtr]$RENDERINGMODE, [IntPtr]$modes[$mode])
				Start-Sleep -Milliseconds 400
				$shots[$mode] = [M]::Shot($h, $x0)
				$label = "{0}-{1}pt-{2}-{3}" -f ($font -replace ' ', ''), (10 + $z), $q, $mode
				$shots[$mode].Save((Join-Path $Out "$label.png"), [System.Drawing.Imaging.ImageFormat]::Png)
			}
			foreach ($mode in $modes.Keys) {
				$ref = if ($mode -eq 'Adaptive') { 'Natural' } else { 'Automatic' }
				foreach ($r in @('Automatic') + $(if ($mode -eq 'Adaptive') { 'Natural' } else { @() })) {
					if ($r -eq $mode) { continue }
					$d = [M]::Diff($shots[$r], $shots[$mode])
					$rows += [pscustomobject]@{ font = $font; pt = 10 + $z; dpi = $dpi; quality = $q; mode = $mode; vs = $r
						diffPixels = $d[0]; meanDiff = [math]::Round($d[1], 1); maxDiff = [math]::Round($d[2], 1); ink = [math]::Round($d[4], 1); inkRef = [math]::Round($d[3], 1) }
				}
			}
			foreach ($b in $shots.Values) { $b.Dispose() }
		}
	}
	[void][M]::SendMessage($h, $SCI_SETFONTRENDERINGPARAMETER, [IntPtr]$RENDERINGMODE, [IntPtr](-1))
	Stop-Npp $n
}
$rows | Export-Csv -NoTypeInformation (Join-Path $Out 'modes.csv')
$rows | Format-Table -AutoSize | Out-String -Width 200
