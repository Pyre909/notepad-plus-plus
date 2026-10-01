# Screenshot the Notepad++ edit view (PrintWindow, so it works even if the window is covered) and measure each text line.
# Usage: measure.ps1 -Label <name>   -> shots\<name>.png, a line per text line in results.csv
param([Parameter(Mandatory)] [string] $Label, [int] $Lines = 4)
$ErrorActionPreference = 'Stop'
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Text; using System.Drawing; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class Npp {
  [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] static extern IntPtr FindWindow(string c, string t);
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  public struct RECT { public int L, T, R, B; }
  public static IntPtr Editor() {
    SetProcessDpiAwarenessContext(new IntPtr(-4));
    IntPtr top = FindWindow("Notepad++", null); if (top == IntPtr.Zero) throw new Exception("no Notepad++ window");
    IntPtr best = IntPtr.Zero; int area = 0;
    EnumChildWindows(top, (h, l) => { var sb = new StringBuilder(64); GetClassName(h, sb, 64);
      if (sb.ToString() == "Scintilla" && IsWindowVisible(h)) { RECT r; GetClientRect(h, out r); int a = (r.R - r.L) * (r.B - r.T); if (a > area) { area = a; best = h; } }
      return true; }, IntPtr.Zero);
    if (best == IntPtr.Zero) throw new Exception("no edit view"); return best;
  }
  public static Bitmap Shot(IntPtr h) {
    RECT r; GetClientRect(h, out r); var bmp = new Bitmap(r.R - r.L, r.B - r.T);
    using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 1 | 2); g.ReleaseHdc(dc); }
    return bmp;
  }
}
'@
$h = [Npp]::Editor()
$x0 = 0; foreach ($m in 0..4) { $x0 += [int][Npp]::SendMessage($h, 2243, [IntPtr]$m, [IntPtr]0) }   # SCI_GETMARGINWIDTHN
$lineH = [int][Npp]::SendMessage($h, 2279, [IntPtr]0, [IntPtr]0)                                        # SCI_TEXTHEIGHT
$tech = [int][Npp]::SendMessage($h, 2631, [IntPtr]0, [IntPtr]0)                                         # SCI_GETTECHNOLOGY
$bmp = [Npp]::Shot($h)
$dir = Join-Path $PSScriptRoot 'shots'; New-Item -ItemType Directory -Force $dir | Out-Null
$bmp.Save((Join-Path $dir "$Label.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$rows = foreach ($i in 0..($Lines - 1)) {
	$y0 = $i * $lineH; $y1 = [Math]::Min($y0 + $lineH, $bmp.Height)
	# background = the most common colour of the line
	$count = @{}; for ($y = $y0; $y -lt $y1; $y += 2) { for ($x = $x0; $x -lt $bmp.Width; $x += 3) { $c = $bmp.GetPixel($x, $y).ToArgb(); $count[$c] = 1 + [int]$count[$c] } }
	$bg = [System.Drawing.Color]::FromArgb(($count.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key)
	$bgMin = [Math]::Min($bg.R, [Math]::Min($bg.G, $bg.B))
	$ink = 0; $left = $bmp.Width; $right = -1; $colored = 0
	for ($y = $y0; $y -lt $y1; $y++) { for ($x = $x0; $x -lt $bmp.Width; $x++) {
		$p = $bmp.GetPixel($x, $y); $d = $bgMin - [Math]::Min($p.R, [Math]::Min($p.G, $p.B))
		if ($d -gt 16) { $ink += $d; if ($x -lt $left) { $left = $x }; if ($x -gt $right) { $right = $x }
			if (([Math]::Max($p.R, [Math]::Max($p.G, $p.B)) - [Math]::Min($p.R, [Math]::Min($p.G, $p.B))) -gt 40 -and $i % 2 -eq 1) { $colored++ } } } }
	[pscustomobject]@{ label = $Label; tech = $tech; line = $i + 1; kind = $(if ($i % 2) { 'regular' } else { 'bold' }); lineHeight = $lineH
		ink = [Math]::Round($ink / 1000.0, 1); width = $right - $left + 1; colorFringePx = $colored }
}
$rows | Export-Csv -Append -NoTypeInformation (Join-Path $PSScriptRoot 'results.csv')
$rows | Format-Table -AutoSize | Out-String
