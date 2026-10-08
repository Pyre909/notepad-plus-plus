# The 100% view: each icon's original 16x16 bitmap next to the redraw at 16 px, and the redraw greyed (disabled), zoomed.
# Windows PowerShell 5.1.
param([string] $Orig = 'C:\Users\stephensamaniego\src\npp\PowerEditor\src\icons\standard\toolbar', [int] $Zoom = 6,
	[int] $PerRow = 4, [int] $Size = 16, [string] $Out = "$PSScriptRoot\at16.png")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$names = @(Get-ChildItem "$PSScriptRoot\svg" -Filter *.svg | Sort-Object Name | ForEach-Object BaseName)
$face = [Drawing.Color]::FromArgb(0xF0, 0xF0, 0xF0)
$cell = 3 * ($Size * $Zoom + 8) + 10; $rowH = $Size * $Zoom + 22
$rows = [math]::Ceiling($names.Count / $PerRow)
$sheet = New-Object Drawing.Bitmap ([int]($PerRow * $cell)), ([int]($rows * $rowH))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear($face); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = New-Object Drawing.Font 'Segoe UI', 8
function Composite([string] $path) {   # the PNG on the toolbar colour
	$src = [Drawing.Image]::FromFile($path); $o = New-Object Drawing.Bitmap $src.Width, $src.Height
	$gg = [Drawing.Graphics]::FromImage($o); $gg.Clear($face); $gg.DrawImage($src, 0, 0, $src.Width, $src.Height); $gg.Dispose(); $src.Dispose(); return $o
}
for ($i = 0; $i -lt $names.Count; $i++) {
	$n = $names[$i]; $x = ($i % $PerRow) * $cell; $y = [math]::Floor($i / $PerRow) * $rowH
	$g.DrawString("$n (orig | new | greyed)", $font, [Drawing.Brushes]::Black, $x + 2, $y + 2)
	$bmp = New-Object Drawing.Bitmap (Join-Path $Orig "$n.bmp"); $o = New-Object Drawing.Bitmap 16, 16
	$key = $bmp.GetPixel(0, 0).ToArgb()
	for ($yy = 0; $yy -lt 16; $yy++) { for ($xx = 0; $xx -lt 16; $xx++) { $c = $bmp.GetPixel($xx, $yy); if ($c.ToArgb() -eq $key -or ($c.R -eq 192 -and $c.G -eq 192 -and $c.B -eq 192)) { $c = $face }; $o.SetPixel($xx, $yy, $c) } }
	$bmp.Dispose()
	$imgs = @($o, (Composite "$PSScriptRoot\png\$n-$Size.png"), (Composite "$PSScriptRoot\png\$($n)_dis-$Size.png"))
	$cx = $x + 4
	foreach ($im in $imgs) {
		$g.DrawImage($im, (New-Object Drawing.Rectangle $cx, ($y + 18), ($im.Width * $Zoom), ($im.Height * $Zoom)), (New-Object Drawing.Rectangle 0, 0, $im.Width, $im.Height), 'Pixel')
		$cx += $Size * $Zoom + 8; $im.Dispose()
	}
}
$g.Dispose(); $sheet.Save($Out, [Drawing.Imaging.ImageFormat]::Png); "-> $Out"
