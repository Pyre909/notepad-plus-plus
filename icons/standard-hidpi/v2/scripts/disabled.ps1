# The disabled (greyed) icons: png\<name>-<size>.png -> png\<name>_dis-<size>.png. Luminance squeezed into a light grey
# range (96-216), seven eighths opaque. Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class Dis {
	public static void Make(string src, string dst) {
		using (var b = new Bitmap(src)) {
			var o = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
			for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) {
				Color c = b.GetPixel(x, y);
				int l = (int)(0.3 * c.R + 0.59 * c.G + 0.11 * c.B);
				int g = 96 + l * 120 / 255;
				o.SetPixel(x, y, Color.FromArgb(c.A * 7 / 8, g, g, g));
			}
			o.Save(dst, ImageFormat.Png); o.Dispose();
		}
	}
}
'@
foreach ($f in Get-ChildItem "$PSScriptRoot\png" -Filter *.png | Where-Object { $_.Name -notmatch '_dis-' }) {
	[Dis]::Make($f.FullName, (Join-Path $f.DirectoryName ($f.Name -replace '-(\d+)\.png$', '_dis-$1.png')))
}
'disabled PNGs: ' + (Get-ChildItem "$PSScriptRoot\png" -Filter *_dis-*.png).Count
